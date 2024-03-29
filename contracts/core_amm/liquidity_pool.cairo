%lang starknet

from helpers import max, _get_value_of_position, min, _get_premia_with_fees, fromUint256_balance, toInt_balance, fromInt_balance, split_option_locked_capital
from interface_lptoken import ILPToken
from interface_option_token import IOptionToken

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import abs_value, assert_not_zero, assert_le_felt
from starkware.cairo.common.math_cmp import is_nn, is_not_zero//, is_le
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_mul,
    uint256_add,
    uint256_sub,
    uint256_unsigned_div_rem,
    uint256_le,
    uint256_eq,
    uint256_signed_le,
    assert_uint256_lt,
    uint256_signed_nn,
)
from starkware.starknet.common.syscalls import get_contract_address
from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.access.ownable.library import Ownable


//
// @title Liquidity Pool module
//


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Other get functions
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

// @notice Retrieves the value of the position within the pool
// @dev Returns a total value of pools position (sum of value of all options held by pool).
// @dev Goes through all options in storage var "available_options"... is able to iterate by i
// @dev (from 0 to n)
// @dev It gets 0 from available_option(n), if the n-1 is the "last" option.
// @dev Used in get_lptokens_for_underlying, which is why it isn't in view.cairo.
// @param lptoken_address: Address of the liquidity pool token
// @return res: Value of the position within specified liquidity pool
@view
func get_value_of_pool_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (res: Math64x61_) {
    alloc_locals;

    let (res) = _get_value_of_pool_position(lptoken_address, 0);
    return (res = res);
}


// @notice Retrieves the value of a single position, independent of the holder.
// @param option: Struct containing option definition data
// @param position_size: Size of the position, in terms of Math64x61
// @param option_type: Type of the option 0 for Call, 1 for Put
// @param current_volatility: Current volatility of given option in the AMM, in terms of Math64x61
// @return position_value: Value of the position
@view
func get_value_of_position{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option: Option,
    position_size: Math64x61_,
    option_type: OptionType,
    current_volatility: Math64x61_
) -> (position_value: Math64x61_){
    let (lptoken_address) = get_lptoken_address_for_given_option(
        option.quote_token_address,
        option.base_token_address,
        option.option_type
    );
    let (pool_volatility_adjustment_speed) = get_pool_volatility_adjustment_speed(lptoken_address);
    let (res) = _get_value_of_position(
        option,
        position_size,
        option_type,
        current_volatility,
        pool_volatility_adjustment_speed
    );
    return (res,);
}


// @notice Helper function for retrieving the value of a single option position within the pool
// @param lptoken_address: Address of the liquidity pool token
// @param index: Current index
// @return res: Value of the position within specified liquidity pool
func _get_value_of_pool_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, index: Int
) -> (res: Math64x61_) {
    alloc_locals;

    let (option) = get_available_options(lptoken_address, index);

    // Because of how the defined options are stored we have to verify that we have not run
    // at the end of the stored values. The end is with "empty" Option.
    let option_sum = option.maturity + option.strike_price;
    if (option_sum == 0) {
        return (res = 0);
    }

    // Get value of option at index "index"
    // In case of long position in given option, the value is equal to premia - fees.
    // In case of short position the value is equal to (locked capital - premia - fees).
    //      - the value of option is comparable to how the locked capital would be split.
    //        The option holder (long) would get equivalent to premia and the underwriter (short)
    //        would get the remaining locked capital.
    // Both scaled by the size of position.
    // option position is measured in base token (ETH in case of ETH/USD) that's why
    // the fromUint256_balance uses option.base_token_address
    let (_option_position) = get_option_position(
        lptoken_address,
        option.option_side,
        option.maturity,
        option.strike_price
    );

    // If option position is 0, the value of given position is zero.
    if (_option_position == 0) {
        let (value_of_rest_of_the_pool_) = _get_value_of_pool_position(
            lptoken_address, index = index + 1
        );
        return (res = value_of_rest_of_the_pool_);
    }

    let (current_block_time) = get_block_timestamp();
    with_attr error_message("Option is not yet settled, please wait") {
        assert_le_felt(current_block_time, option.maturity);
    }

    let (current_volatility) = get_pool_volatility_auto(lptoken_address, option.maturity, option.strike_price);

    with_attr error_message("Failed getting value of position in _get_value_of_pool_position"){
        let (value_of_option) = get_value_of_position(
            option,
            _option_position,
            option.option_type,
            current_volatility,
        );
    }

    // Get value of the remaining pool
    let (value_of_rest_of_the_pool) = _get_value_of_pool_position(
        lptoken_address, index = index + 1
    );

    // Combine the two values
    let res = Math64x61.add(value_of_option, value_of_rest_of_the_pool);

    return (res = res);
}


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Provide/remove liquidity
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


// @notice Calculates how many LP tokens correspond to the given amount of underlying token
// @dev Quote or base tokens are used based on the pool being put/call
// @param lptoken_address: Address of the liquidity pool token
// @param underlying_amt: Amount of underlying tokens, in Uint256!!!
// @return lpt_amt: How many LP tokens correspond to the given amount of underlying token
//      in Uint256!!!
@view
func get_lptokens_for_underlying{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    underlying_amt: Uint256
) -> (lpt_amt: Uint256) {
    alloc_locals;

    with_attr error_message("Failed to get free_capital in get_lptokens_for_underlying"){
        let (free_capital: Uint256) = get_unlocked_capital(lptoken_address);
    }

    with_attr error_message("Failed to value pools position in get_lptokens_for_underlying"){
        let (value_of_position_Math64) = get_value_of_pool_position(lptoken_address);
        let (currency_address) = get_underlying_token_address(lptoken_address);
        let value_of_position = toUint256_balance(value_of_position_Math64, currency_address);
    }

    with_attr error_message("Failed to get value of pool get_lptokens_for_underlying"){
        let (value_of_pool, _) = uint256_add(free_capital, value_of_position);
    }

    if (value_of_pool.low == 0 and value_of_pool.high == 0) {
        return (underlying_amt,);
    }

    with_attr error_message("Failed to get to_mint get_lptokens_for_underlying"){
        let (lpt_supply) = ILPToken.totalSupply(contract_address=lptoken_address);
        let (quot, rem) = uint256_unsigned_div_rem(lpt_supply, value_of_pool);
        let (to_mint_low, to_mint_high) = uint256_mul(quot, underlying_amt);
        assert to_mint_high.low = 0;
    }

    with_attr error_message("Failed to get to_mint_additional get_lptokens_for_underlying"){
        let (to_div_low, to_div_high) = uint256_mul(rem, underlying_amt);
        assert to_div_high.low = 0;
        let (to_mint_additional_quot, to_mint_additional_rem) = uint256_unsigned_div_rem(
            to_div_low, value_of_pool
        );  // to_mint_additional_rem goes to liq pool // treasury
    }

    with_attr error_message("Failed to get mint_total get_lptokens_for_underlying"){
        let (mint_total, carry) = uint256_add(to_mint_additional_quot, to_mint_low);
        assert carry = 0;
    }
    return (mint_total,);
}

// @notice Computes the amount of underlying token that corresponds to a given amount of LP token
// @dev Doesn't take into account whether this underlying is actually free to be withdrawn.
// @dev computes this essentially: my_underlying = (total_underlying/total_lpt)*my_lpt
// @dev notation used: ... = (a)*my_lpt = b
// @param lptoken_address: Address of the liquidity pool token
// @param lpt_amt: Amount of liquidity pool tokens, in Uint256!!!
// @return underlying_amt: Amount of underlying token that correspond to the given amount of
//      LP token, in Uint256!!!
@view
func get_underlying_for_lptokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    lpt_amt: Uint256
) -> (underlying_amt: Uint256) {
    alloc_locals;

    let (total_lpt: Uint256) = ILPToken.totalSupply(contract_address=lptoken_address);

    with_attr error_message(
        "Failed to get free_capital_Math64 in get_underlying_for_lptokens, {lptoken_address}, {lpt_amt}"
    ){
        let (free_capital) = get_unlocked_capital(lptoken_address);
    }

    with_attr error_message("Failed to get value_of_position in get_underlying_for_lptokens"){
        let (value_of_position_Math64) = get_value_of_pool_position(lptoken_address);
        let (currency_address) = get_underlying_token_address(lptoken_address);
        let value_of_position = toUint256_balance(value_of_position_Math64, currency_address);
    }
    
    with_attr error_message("Failed to get total_underlying_amt in get_underlying_for_lptokens"){
        let (total_underlying_amt, _) = uint256_add(free_capital, value_of_position);
    }

    with_attr error_message("Failed to get to_burn_additional_quot in get_underlying_for_lptokens"){
        let (a_quot, a_rem) = uint256_unsigned_div_rem(total_underlying_amt, total_lpt);
        let (b_low, b_high) = uint256_mul(a_quot, lpt_amt);
        assert b_high.low = 0;  // bits that overflow uint256 after multiplication
        let (tmp_low, tmp_high) = uint256_mul(a_rem, lpt_amt);
        assert tmp_high.low = 0;
        let (to_burn_additional_quot, to_burn_additional_rem) = uint256_unsigned_div_rem(
            tmp_low, total_lpt
        );
    }
    with_attr error_message("Failed to get to_burn in get_underlying_for_lptokens"){
        let (to_burn, carry) = uint256_add(to_burn_additional_quot, b_low);
        assert carry = 0;
    }
    return (to_burn,);
}


// @notice Adds a new liqudity pool through registering LP token in the AMM.
// @dev This function initializes new pool
// @param quote_token_address: Address of the quote token (USDC in ETH/USDC)
// @param base_token_address: Address of the base token (ETH in ETH/USDC)
// @param option_type: Type of the option 0 for Call, 1 for Put
// @param lptoken_address: Address of the liquidity pool token
// @param pooled_token_addr: Address of the pooled token
// @param volatility_adjustment_speed: Constant that determines how fast the volatility is changing
// @param max_lpool_bal: Maximum balance of the bool for giver pooled token
@external
func add_lptoken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    lptoken_address: Address,
    pooled_token_addr: Address,
    volatility_adjustment_speed: Math64x61_,
    max_lpool_bal: Uint256
){
    alloc_locals;

    // 1) Check that owner (and no other entity) is adding the lptoken
    Proxy.assert_only_admin();

    with_attr error_message("Received unknown option type(={option_type}) in add_lptoken"){
        assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;
    }

    // Check that the lptoken's address has not been registered yet
    fail_if_existing_pool_definition_from_lptoken_address(lptoken_address);

    // Check that base/quote token even exists - use total supply for now I guess
    let (supply_base) = IERC20.totalSupply(base_token_address);
    let (supply_quote) = IERC20.totalSupply(quote_token_address);

    with_attr error_message("Base token has total supply lower than 1"){
        assert_uint256_le(Uint256(1, 0), supply_base);
    }
    with_attr error_message("Quote token has total supply lower than 1"){
        assert_uint256_le(Uint256(1, 0), supply_quote);
    }

    // 2) Add lptoken_address into a storage_var of lptoken_addresses
    let (lptoken_usable_index) = get_available_lptoken_addresses_usable_index(0);
    set_available_lptoken_addresses(lptoken_usable_index, lptoken_address);

    // Check if it hasn't been added before
    with_attr error_message("LPToken has already been added") {
        fail_if_existing_pool_definition_from_lptoken_address(lptoken_address);
    }

    // 3) Update following
    set_lptoken_address_for_given_option(
        quote_token_address, base_token_address, option_type, lptoken_address
    );

    let pool = Pool(
        quote_token_address=quote_token_address,
        base_token_address=base_token_address,
        option_type=option_type,
    );
    set_pool_definition_from_lptoken_address(lptoken_address, pool);

    set_option_type(lptoken_address, option_type);
    if (option_type == OPTION_CALL) {
        // base tokens (ETH in case of ETH/USDC) for call option
        set_underlying_token_address(lptoken_address, base_token_address);
    } else {
        // quote tokens (USDC in case of ETH/USDC) for put option
        set_underlying_token_address(lptoken_address, quote_token_address);
    }

    // 4) Set the volality adjustment speed (same const across pool)
    set_pool_volatility_adjustment_speed(lptoken_address, volatility_adjustment_speed);

    // 5) Set max lpool balance
    // Overwrites the balance for all other pools with the same underlying token.
    set_max_lpool_balance(pooled_token_addr, max_lpool_bal);

    return ();
}


// @notice Mints LP tokens and deposits liquidity into the LP
// @dev Assumes the underlying token is already approved (directly call approve() on the token being
// @dev deposited to allow this contract to claim them)
// @param pooled_token_addr: Address that should correspond to the underlying token address of the pool
// @param quote_token_address: Address of the quote token (USDC in ETH/USDC)
// @param base_token_address: Address of the base token (ETH in ETH/USDC)
// @param option_type: Type of the option 0 for Call, 1 for Put
// @param amount: Amount of underlying token to deposit - in terms of Uint256!!!
@external
func deposit_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: Address,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    amount: Uint256
) {
    alloc_locals;

    ReentrancyGuard.start();

    with_attr error_message("Amount must be > 0"){
        assert_uint256_le(Uint256(0, 0), amount);
    }
    with_attr error_message("pooled_token_addr address is zero"){
        assert_not_zero(pooled_token_addr);
    }
    with_attr error_message("quote_token_address address is zero"){
        assert_not_zero(quote_token_address);
    }
    with_attr error_message("base_token_address address is zero"){
        assert_not_zero(base_token_address);
    }

    let (caller_addr) = get_caller_address();
    let (own_addr) = get_contract_address();

    with_attr error_message("Caller address is zero"){
        assert_not_zero(caller_addr);
    }
    with_attr error_message("Owner address is zero"){
        assert_not_zero(own_addr);
    }

    let (lptoken_address) = get_lptoken_address_for_given_option(
        quote_token_address, base_token_address, option_type
    );

    // Test the pooled_token_addr corresponds to the underlying token address of the pool,
    // that is defined by the quote_token_address, base_token_address and option_type
    with_attr error_message(
        "pooled_token_addr does not match the selected pool underlying token address deposit_liquidity"
    ){
        let underlying_token_address = get_underlying_from_option_data(option_type, base_token_address, quote_token_address);
        assert underlying_token_address = pooled_token_addr;
    }

    with_attr error_message("Failed to calculate lp tokens to be minted"){
        // Calculates how many lp tokens will be minted for given amount of provided capital.
        let (mint_amount) = get_lptokens_for_underlying(lptoken_address, amount);
    }

    DepositLiquidity.emit(
        caller=caller_addr,
        lp_token=lptoken_address,
        capital_transfered=amount,
        lp_tokens_minted=mint_amount,
    );

    // Update the lpool_balance after the mint_amount has been computed
    // (get_lptokens_for_underlying uses lpool_balance)
    with_attr error_message("Failed to update the lpool_balance"){
        let (current_balance) = get_lpool_balance(lptoken_address);
        let (new_pb: Uint256, carry: felt) = uint256_add(current_balance, amount);
        assert carry = 0;
        set_lpool_balance(lptoken_address, new_pb);
    }

    with_attr error_message("lpool balance exceeds set maximum"){
        let (max_balance) = get_max_lpool_balance(pooled_token_addr);
        assert_uint256_le(current_balance, max_balance);
    }

    with_attr error_message("Failed to mint lp tokens"){
        // Mint LP tokens
        ILPToken.mint(contract_address=lptoken_address, to=caller_addr, amount=mint_amount);
    }

    with_attr error_message("Failed to transfer token from account to pool"){
        // Transfer tokens to pool.
        IERC20.transferFrom(
            contract_address=pooled_token_addr, sender=caller_addr, recipient=own_addr, amount=amount
        );
    }

    ReentrancyGuard.end();

    return ();
}


// @notice Withdraw liquidity from the LP
// @dev withdraws liquidity only if there is enough available liquidity (ie enough unlocked
//      capital). If that is not the case the transaction fails.
// @param pooled_token_addr: Address that should correspond to the underlying token address of the pool
// @param quote_token_address: Address of the quote token (USDC in ETH/USDC)
// @param base_token_address: Address of the base token (ETH in ETH/USDC)
// @param option_type: Type of the option 0 for Call, 1 for Put
// @param lp_token_amount: LP token amount in terms of LP tokens, not underlying tokens
//       as in deposit_liquidity
@external
func withdraw_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: Address,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    lp_token_amount: Uint256
) {
    alloc_locals;

    ReentrancyGuard.start();

    let (caller_addr_) = get_caller_address();
    local caller_addr = caller_addr_;
    with_attr error_message("caller_addr is zero in withdraw_liquidity"){
        assert_not_zero(caller_addr);
    }

    let (lptoken_address: felt) = get_lptoken_address_for_given_option(
        quote_token_address, base_token_address, option_type
    );

    with_attr error_message("LP token amount must be > 0"){
        assert_uint256_le(Uint256(0, 0), lp_token_amount);
    }

    // Test the pooled_token_addr corresponds to the underlying token address of the pool,
    // that is defined by the quote_token_address, base_token_address and option_type
    with_attr error_message(
        "pooled_token_addr does not match the selected pool underlying token address withdraw_liquidity"
    ){
        let underlying_token_address = get_underlying_from_option_data(option_type, base_token_address, quote_token_address);
        assert underlying_token_address = pooled_token_addr;
    }

    // Get the amount of underlying that corresponds to given amount of lp tokens

    let lp_token_amount_low = lp_token_amount.low;
    with_attr error_message(
        "Failed to calculate underlying, {pooled_token_addr}, {quote_token_address}, {base_token_address}, {option_type}, {lp_token_amount_low}"
    ){
        let (underlying_amount_uint256) = get_underlying_for_lptokens(lptoken_address, lp_token_amount);
    }

    with_attr error_message(
        "Not enough 'cash' available funds in pool. Wait for it to be released from locked capital in withdraw_liquidity"
    ){
        let (free_capital_uint256: Uint256) = get_unlocked_capital(lptoken_address);

        // One additional check
        assert_uint256_le(underlying_amount_uint256, free_capital_uint256);
        assert_not_zero(free_capital_uint256.low);
    }

    WithdrawLiquidity.emit(
        caller=caller_addr,
        lp_token=lptoken_address,
        capital_transfered=underlying_amount_uint256,
        lp_tokens_burned=lp_token_amount,
    );

    with_attr error_message("Failed to write new lpool_balance in withdraw_liquidity"){
        // Update that the capital in the pool (including the locked capital).
        let (current_balance: Uint256) = get_lpool_balance(lptoken_address);
        let (unlocked_capital: Uint256) = get_unlocked_capital(lptoken_address);
        let (new_pb: Uint256) = uint256_sub(current_balance, underlying_amount_uint256);

        // Dont use Math.fromUint here since it would multiply the number by FRACT_PART AGAIN
        set_lpool_balance(lptoken_address, new_pb);
    }

    with_attr error_message("Failed to transfer token from pool to account in withdraw_liquidity"){
        // Transfer underlying (base or quote depending on call/put)
        IERC20.transfer(
            contract_address=pooled_token_addr,
            recipient=caller_addr,
            amount=underlying_amount_uint256
        );
    }

    with_attr error_message("Failed to burn lp token in withdraw_liquidity"){
        // Burn LP tokens
        ILPToken.burn(contract_address=lptoken_address, account=caller_addr, amount=lp_token_amount);
    }

    ReentrancyGuard.end();

    return ();
}


// @notice Helper function for expiring pool's options.
// @dev It basically adjusts the internal state of the AMM.
// @param lptoken_address: Address of the LP token
// @param long_value: Pool's long position
// @param short_value: Pool's short position
// @param option_size: Size of the position
// @param option_side: Option's side from the perspective of the pool
// @param maturity: Option's maturity
// @param strike_price: Option's strike price
func adjust_lpool_balance_and_pool_locked_capital_expired_options{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address,
    long_value: Math64x61_,
    short_value: Math64x61_,
    option_size: Int,
    option_side: OptionSide,
    maturity: Int,
    strike_price: Math64x61_
) {
    alloc_locals;

    let (lpool_underlying_token: Address) = get_underlying_token_address(lptoken_address);
    let long_value_uint256: Uint256 = toUint256_balance(long_value, lpool_underlying_token);
    let short_value_uint256: Uint256 = toUint256_balance(short_value, lpool_underlying_token);

    let (current_lpool_balance: Uint256) = get_lpool_balance(lptoken_address);
    let (current_locked_balance: Uint256) = get_pool_locked_capital(lptoken_address);

    if (option_side == TRADE_SIDE_LONG) {
        // Pool is LONG
        // Capital locked by user(s)
        // Increase lpool_balance by long_value, since pool either made profit (profit >=0).
        //      The cost (premium) was paid before.
        // Nothing locked by pool -> locked capital not affected
        // Unlocked capital should increas by profit from long option, in total:
        //      Unlocked capital = lpool_balance - pool_locked_capital
        //      diff_capital = diff_lpool_balance - diff_pool_locked
        //      diff_capital = long_value - 0

        let (new_lpool_balance: Uint256, carry: felt) = uint256_add(current_lpool_balance, long_value_uint256);
        assert carry = 0;
        set_lpool_balance(lptoken_address, new_lpool_balance);
    } else {
        // Pool is SHORT
        // Decrease the lpool_balance by the long_value.
        //      The extraction of long_value might have not happened yet from transacting the tokens.
        //      But from perspective of accounting it is happening now.
        //          -> diff lpool_balance = -long_value
        // Decrease the pool_locked_capital by the locked capital. Locked capital for this option
        // (option_size * strike in terms of pool's currency (ETH vs USD))
        //          -> locked capital = long_value + short_value
        //          -> diff pool_locked_capital = - locked capital
        //      You may ask why not just the short_value. That is because the total capital
        //      (locked + unlocked) is decreased by long_value as in the point above (loss from short).
        //      The unlocked capital is increased by short_value - what gets returned from locked.
        //      To check the math
        //          -> lpool_balance = pool_locked_capital + unlocked
        //          -> diff lpool_balance = diff pool_locked_capital + diff unlocked
        //          -> -long_value = -locked capital + short_value
        //          -> -long_value = -(long_value + short_value) + short_value
        //          -> -long_value = -long_value - short_value + short_value
        //          -> -long_value +long_value = - short_value + short_value
        //          -> 0=0
        // The long value is left in the pool for the long owner to collect it.

        let (new_lpool_balance: Uint256) = uint256_sub(current_lpool_balance, long_value_uint256);
        with_attr error_message("Not enough capital in the pool - new_lpool_balance negative") {
            let (res1: felt) = uint256_signed_le(long_value_uint256, current_lpool_balance);
            assert res1 = 1;
        }

        // Substracting the combination of long and short rather than separately because of rounding error
        // More specifically transfering the combo to uint256 rather than separate values because
        // of the rounding error

        let (long_plus_short_value, carry) = uint256_add(long_value_uint256, short_value_uint256);
        assert carry = 0;

        let (new_locked_balance: Uint256) = uint256_sub(current_locked_balance, long_plus_short_value);
        with_attr error_message("Not enough capital in the pool - new_locked_balance negative") {
            let (res2: felt) = uint256_signed_le(long_plus_short_value, current_locked_balance);
            assert res2 = 1;
        }

        with_attr error_message("Not enough capital in the pool") {
            // This will never happen since the capital to pay the users is always locked.
            let ZERO: Uint256 = Uint256(0, 0);
            let (res: felt) = uint256_signed_le(ZERO, new_lpool_balance);
            assert res = 1;
            let (res_: felt) = uint256_signed_le(ZERO, new_locked_balance);
            assert res_ = 1;
        }

        set_lpool_balance(lptoken_address, new_lpool_balance);
        set_pool_locked_capital(lptoken_address, new_locked_balance);
    }
    return ();
}


// @notice Expires option token but only for pool.
// @dev First pool's position has to be expired, before any user's position is expired (settled).
// @param lptoken_address: Address of the LP token
// @param option_side: Option's side from the perspective of the pool
// @param strike_price: Option's strike price
// @param maturity: Option's maturity
@external
func expire_option_token_for_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_side: OptionSide,
    strike_price: Math64x61_,
    maturity: Int,
) -> () {
    alloc_locals;

    ExpireOptionTokenForPool.emit(
        lptoken_address=lptoken_address,
        option_side=option_side,
        strike_price=strike_price,
        maturity=maturity,
    );

    let (option) = _get_option_info(
        lptoken_address=lptoken_address,
        option_side=option_side,
        strike_price=strike_price,
        maturity=maturity,
        starting_index=0
    );

    let quote_token_address = option.quote_token_address;
    let base_token_address = option.base_token_address;

    let option_type = option.option_type;

    // pool's position... has to be nonnegative since the position is per side (long/short)
    let (option_size) = get_option_position(lptoken_address, option_side, maturity, strike_price);
    
    if (option_size == 0){
        // Pool's position is zero, there is nothing to expire.
        // This also checks that the option exists (if it doesn't storage_var returns 0).
        return ();
    }

    // From now on we know that pool's position is positive -> option_size > 0.

    // Make sure the contract is ready to expire
    let (current_block_time) = get_block_timestamp();
    let is_ripe = is_le(maturity, current_block_time);
    with_attr error_message("Contract isn't mature yet") {
        assert is_ripe = 1;
    }

    // Get terminal price of the option.
    let (empiric_key) = get_empiric_key(quote_token_address, base_token_address);
    let (_terminal_price: Math64x61_) = get_terminal_price(empiric_key, maturity);
    let (terminal_price: Math64x61_) = account_for_stablecoin_divergence(_terminal_price, quote_token_address, maturity);

    local optsize = option_size;
    let option_size_m64x61 = fromInt_balance(option_size, base_token_address);
    local optsize64 = option_size_m64x61;
    local str = strike_price;
    local term = terminal_price;
    with_attr error_message("unable to split_option_locked_capital in expire_option_token_for_pool optsize {optsize}, optsize64 {optisize64} strike {str} term {term}"){
    let (long_value, short_value)  = split_option_locked_capital(
        option_type, option_side, option_size_m64x61, strike_price, terminal_price
    );
}

    // Adjusts only the lpool_balance and pool_locked_capital storage_vars
    with_attr error_message("unable to adjust_lpool_balance_and_pool_locked_capital_expired_options in expire_option_token_for_pool"){
        adjust_lpool_balance_and_pool_locked_capital_expired_options(
            lptoken_address=lptoken_address,
            long_value=long_value,
            short_value=short_value,
            option_size=option_size,
            option_side=option_side,
            maturity=maturity,
            strike_price=strike_price
        );
    }

    let (current_pool_position) = get_option_position(
        lptoken_address, option_side, maturity, strike_price
    );

    let new_pool_position = current_pool_position - option_size;
    with_attr error_message("new_pool_position is negative in expire_option_token_for_pool") {
        assert_nn(new_pool_position);
        assert_le(option_size, current_pool_position);
    }
    // We have to adjust the pools option position too.
    set_option_position(lptoken_address, option_side, maturity, strike_price, 0);

    return ();
}
