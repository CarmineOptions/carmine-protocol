%lang starknet

// Part of the main contract to not add complexity by having to transfer tokens between our own contracts
from helpers import max, _get_value_of_position, min, _get_premia_with_fees, fromUint256_balance, toInt_balance, fromInt_balance
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


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Other get functions
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


// Returns a total value of pools position (sum of value of all options held by pool).
// Goes through all options in storage var "available_options"... is able to iterate by i
// (from 0 to n)
// It gets 0 from available_option(n), if the n-1 is the "last" option.
// This could possibly use map from https://github.com/onlydustxyz/cairo-streams/
// If this doesn't look "good", there is an option to have the available_options instead of having
// the argument i, it could have no argument and return array (it might be easier for the map above)
// Used in get_lptokens_for_underlying, which is why it isn't in view.cairo.
@view
func get_value_of_pool_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (res: Math64x61_) {
    alloc_locals;

    let (res) = _get_value_of_pool_position(lptoken_address, 0);
    return (res = res);
}


@view
func get_value_of_position{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option: Option,
    position_size: Math64x61_,
    option_type: OptionType,
    current_volatility: Math64x61_,
    current_pool_balance: Math64x61_
) -> (position_value: Math64x61_){
    let (res) = _get_value_of_position(
        option,
        position_size,
        option_type,
        current_volatility,
        current_pool_balance
    );
    return (res,);
}


func _get_value_of_pool_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, index: Int
) -> (res: Math64x61_) {
    alloc_locals;

    let (option) = available_options.read(lptoken_address, index);

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
    let (pool: Pool) = get_pool_definition_from_lptoken_address(lptoken_address);
    let (_option_position) = option_position_.read(
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

    let (current_volatility) = get_pool_volatility(lptoken_address, option.maturity);

    let (current_pool_balance_uint256) = get_unlocked_capital(lptoken_address);
    let (underlying) = get_underlying_token_address(lptoken_address);
    let current_pool_balance: Math64x61_ = fromUint256_balance(current_pool_balance_uint256, underlying);

    with_attr error_message("Failed getting value of position in _get_value_of_pool_position"){
        let (value_of_option) = get_value_of_position(
            option,
            _option_position,
            option.option_type,
            current_volatility,
            current_pool_balance
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


func get_lptokens_for_underlying{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    underlying_amt: Uint256
) -> (lpt_amt: Uint256) {
    // Takes in underlying_amt in quote or base tokens (based on the pool being put/call).
    // Returns how much lp tokens correspond to capital of size underlying_amt

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

// computes what amt of underlying corresponds to a given amt of lpt.
// Doesn't take into account whether this underlying is actually free to be withdrawn.
// computes this essentially: my_underlying = (total_underlying/total_lpt)*my_lpt
// notation used: ... = (a)*my_lpt = b
@view
func get_underlying_for_lptokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    lpt_amt: Uint256
) -> (underlying_amt: Uint256) {
    // Takes in lpt_amt in terms of amount of lp tokens.
    // Returns how much underlying in quote or base tokens (based on the pool being put/call)
    // corresponds to given lp tokens.

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



// FIXME 4: add unittest that
// amount = get_underlying_for_lptokens(addr, get_lptokens_for_underlying(addr, amount))
//ie that what you get for lptoken is what you need to get same amount of lptokens


@external
func add_lptoken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    lptoken_address: Address
){
    // This function initializes the pool.

    alloc_locals;

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    // 1) Check that owner (and no other entity) is adding the lptoken
    Proxy.assert_only_admin();

    // 2) Add lptoken_address into a storage_var of lptoken_addresses
    let (lptoken_usable_index) = get_available_lptoken_addresses_usable_index(0);
    set_available_lptoken_addresses(lptoken_usable_index, lptoken_address);

    // Check if it hasn't been added before
    with_attr error_message("LPToken has already been added") {
        let (lptoken_addr) = lptoken_addr_for_given_pooled_token.read(quote_token_address, base_token_address, option_type);
        assert lptoken_addr = 0;
    }

    // 3) Update following
    lptoken_addr_for_given_pooled_token.write(
        quote_token_address, base_token_address, option_type, lptoken_address
    );

    let pool = Pool(
        quote_token_address=quote_token_address,
        base_token_address=base_token_address,
        option_type=option_type,
    );
    set_pool_definition_from_lptoken_address(lptoken_address, pool);

    option_type_.write(lptoken_address, option_type);
    if (option_type == OPTION_CALL) {
        // base tokens (ETH in case of ETH/USDC) for call option
        underlying_token_address.write(lptoken_address, base_token_address);
    } else {
        // quote tokens (USDC in case of ETH/USDC) for put option
        underlying_token_address.write(lptoken_address, quote_token_address);
    }

    return ();
}

// Mints LPToken
// Assumes the underlying token is already approved (directly call approve() on the token being
// deposited to allow this contract to claim them)
// amt is amount of underlying token to deposit (either in base or quote based on call or put pool)
@external
func deposit_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: Address,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    amount: Uint256
) {
    alloc_locals;

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
        let underlying_token = get_underlying_from_option_data(option_type, base_token_address, quote_token_address);
        assert underlying_token_address = pooled_token_addr;
    }

    with_attr error_message("Failed to transfer token from account to pool"){
        // Transfer tokens to pool.
        // We can do this optimistically;
        // any later exceptions revert the transaction anyway. saves some sanity checks
        IERC20.transferFrom(
            contract_address=pooled_token_addr, sender=caller_addr, recipient=own_addr, amount=amount
        );
    }

    with_attr error_message("Failed to calculate lp tokens to be minted"){
        // Calculates how many lp tokens will be minted for given amount of provided capital.
        let (mint_amount) = get_lptokens_for_underlying(lptoken_address, amount);
    }
    with_attr error_message("Failed to mint lp tokens"){
        // Mint LP tokens
        ILPToken.mint(contract_address=lptoken_address, to=caller_addr, amount=mint_amount);
    }

    // Update the lpool_balance after the mint_amount has been computed
    // (get_lptokens_for_underlying uses lpool_balance)
    with_attr error_message("Failed to update the lpool_balance"){
        let (current_balance) = get_lpool_balance(lptoken_address);
        let (new_pb: Uint256, carry: felt) = uint256_add(current_balance, amount);
        assert carry = 0;
        set_lpool_balance(lptoken_address, new_pb);
    }

    return ();
}


@external
func withdraw_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: Address,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    lp_token_amount: Uint256
) {
    // lp_token_amount is in terms of lp tokens, not underlying as deposit_liquidity

    alloc_locals;

    let (caller_addr_) = get_caller_address();
    local caller_addr = caller_addr_;
    with_attr error_message("caller_addr is zero in withdraw_liquidity"){
        assert_not_zero(caller_addr);
    }
    let (own_addr) = get_contract_address();
    with_attr error_message("own_addr is zero in withdraw_liquidity"){
        assert_not_zero(own_addr);
    }

    let (lptoken_address: felt) = get_lptoken_address_for_given_option(
        quote_token_address, base_token_address, option_type
    );

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

        let assert_res: Uint256 = uint256_sub(free_capital_uint256, underlying_amount_uint256);
        let ZERO = Uint256(0, 0);
        assert_uint256_le(ZERO, assert_res);
    }

    with_attr error_message("Failed to transfer token from pool to account in withdraw_liquidity"){
        // Transfer underlying (base or quote depending on call/put)
        // We can do this transfer optimistically;
        // any later exceptions revert the transaction anyway. saves some sanity checks
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

    with_attr error_message("Failed to write new lpool_balance in withdraw_liquidity"){
        // Update that the capital in the pool (including the locked capital).
        let (current_balance: Uint256) = get_lpool_balance(lptoken_address);
        let (new_pb: Uint256) = uint256_sub(current_balance, underlying_amount_uint256);

        // Dont use Math.fromUint here since it would multiply the number by FRACT_PART AGAIN
        set_lpool_balance(lptoken_address, new_pb);
    }

    return ();
}


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
    // This function is a helper function used only for expiring POOL'S options.
    // option_side is from perspektive of the pool

    alloc_locals;

    let (lpool_underlying_token: Address) = get_underlying_token_address(lptoken_address);
    let long_value_uint256: Uint256 = toUint256_balance(long_value, lpool_underlying_token);
    let short_value_uint256: Uint256 = toUint256_balance(short_value, lpool_underlying_token);

    let (current_lpool_balance: Uint256) = get_lpool_balance(lptoken_address);
    let (current_locked_balance: Uint256) = get_pool_locked_capital(lptoken_address);
    let (current_pool_position) = get_option_position(
        lptoken_address, option_side, maturity, strike_price
    );
    let current_pool_position_uint256: Uint256 = toUint256_balance(current_pool_position, lpool_underlying_token);

    let new_pool_position = current_pool_position - option_size;
    set_option_position(lptoken_address, option_side, maturity, strike_price, new_pool_position);

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

        // Substracting the combination of long and short rather than separately because of rounding error
        // More specifically transfering the combo to uint256 rather than separate values because
        // of the rounding error

        let (long_plus_short_value, carry) = uint256_add(long_value_uint256, short_value_uint256);
        assert carry = 0;

        let (new_locked_balance: Uint256) = uint256_sub(current_locked_balance, long_plus_short_value);

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


func split_option_locked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: OptionType,
    option_side: OptionSide,
    option_size: Math64x61_,
    strike_price: Math64x61_,
    terminal_price: Math64x61_, // terminal price is price at which option is being settled
) -> (long_value: Math64x61_, short_value: Math64x61_) {
    alloc_locals;

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    if (option_type == OPTION_CALL) {
        // User receives max(0, option_size * (terminal_price - strike_price) / terminal_price) in base token for long
        // User receives (option_size - long_profit) for short
        let price_diff = Math64x61.sub(terminal_price, strike_price);
        let to_be_paid_quote = Math64x61.mul(option_size, price_diff);
        let to_be_paid_base = Math64x61.div(to_be_paid_quote, terminal_price);
        let (to_be_paid_buyer) = max(0, to_be_paid_base);

        let to_be_paid_seller = Math64x61.sub(option_size, to_be_paid_buyer);

        return (to_be_paid_buyer, to_be_paid_seller);
    }

    // For Put option
    // User receives  max(0, option_size * (strike_price - terminal_price)) in base token for long
    // User receives (option_size * strike_price - long_profit) for short
    let price_diff = Math64x61.sub(strike_price, terminal_price);
    let amount_x_diff_quote = Math64x61.mul(option_size, price_diff);
    let (to_be_paid_buyer) = max(0, amount_x_diff_quote);
    let to_be_paid_seller_ = Math64x61.mul(option_size, strike_price);
    let to_be_paid_seller = Math64x61.sub(to_be_paid_seller_, to_be_paid_buyer);

    return (to_be_paid_buyer, to_be_paid_seller);
}


@external
func expire_option_token_for_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_side: OptionSide,
    strike_price: Math64x61_,
    maturity: Int,
) -> () {
    // Side is from perspective of pool!!!

    alloc_locals;

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
    let (terminal_price: Math64x61_) = get_terminal_price(empiric_key, maturity);

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

    // We have to adjust the pools option position too.
    set_option_position(lptoken_address, option_side, maturity, strike_price, 0);

    return ();
}
