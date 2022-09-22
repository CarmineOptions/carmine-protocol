%lang starknet

// Part of the main contract to not add complexity by having to transfer tokens between our own contracts
from interface_lptoken import ILPToken
from interface_option_token import IOptionToken

//  commented out code already imported in amm.cairo
//  from starkware.cairo.common.cairo_builtins import HashBuiltin


from helpers import max
from starkware.cairo.common.math import abs_value
from starkware.cairo.common.math_cmp import is_nn//, is_le
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_mul,
    uint256_add,
    uint256_sub,
    uint256_unsigned_div_rem,
)
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from openzeppelin.token.erc20.IERC20 import IERC20

from contracts.constants import (
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    TRADE_SIDE_SHORT,
    get_opposite_side
)
from contracts.option_pricing_helpers import convert_amount_to_option_currency_from_base




// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Storage vars
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

@storage_var
func lptoken_addr_for_given_pooled_token(pooled_token_addr: felt) -> (res: felt) {
}


// Option type that this pool corresponds to.
@storage_var
func option_type_() -> (option_type: felt) {
}


// Address of the underlying token (for example address of ETH or USD or...).
// Will return base/quote according to option_type
@storage_var
func underlying_token_addres(option_type: felt) -> (res: felt) {
}


// Stores current value of volatility for given pool (option type) and maturity.
@storage_var
func pool_volatility(maturity: Int) -> (volatility: Math64x61_) {
}


// List of available options (mapping from 1 to n to available strike x maturity,
// for n+1 returns zeros). STARTS INDEXING AT 0.
@storage_var
func available_options(order_i: felt) -> (option_side: felt, maturity: felt, strike_price: felt) {
}


// Maping from option params to option address
@storage_var
func option_token_address(
    option_side: felt, maturity: felt, strike_price: felt
) -> (res: felt) {
}


// Mapping from option params to pool's position
@storage_var
func option_position(option_side: felt, maturity: felt, strike_price: felt) -> (res: felt) {
}


// total balance of underlying in the pool (owned by the pool)
// available balance for withdraw will be computed on-demand since
// compute is cheap, storage is expensive on StarkNet currently
// FIXME 1: do we need pooled_token_addr??? if not drop it, if yes, add it all over the place
@storage_var
func lpool_balance(pooled_token_addr: felt) -> (res: Uint256) {
}


// Locked capital owned by the pool... above is lpool_balance describing total capital owned
// by the pool. Ie lpool_balance = pool_locked_capital + pool's unlocked capital
// Note: capital locked by users is not accounted for here.
    // Simple example:
    // - start pool with no position
    // - user sells option (user locks capital), pool pays premia and does not lock capital
    // - there is more "IERC20.balanceOf" in the pool than "pool's locked capital + unlocked capital"
@storage_var
func pool_locked_capital() -> (res: felt) {
}


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// storage_var handlers and helpers
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


@view
func get_pool_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    maturity: Int
) -> (pool_volatility: Math64x61_) {
    let (pool_volatility_) = pool_volatility.read(pool_address, maturity);
    return (pool_volatility_,);
}


func set_pool_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    maturity: Int, volatility: Math64x61_
) {
    // volatility has to be above 1 (in terms of Math64x61.FRACT_PART units...
    // ie volatility = 1 is very very close to 0 and 100% volatility would be
    // volatility=Math64x61.FRACT_PART)
    assert_nn_le(volatility, VOLATILITY_UPPER_BOUND - 1);
    assert_nn_le(VOLATILITY_LOWER_BOUND, volatility);
    pool_volatility.write(pool_address, maturity, volatility);
    return ();
}


func get_unlocked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token_adress: felt
) -> (unlocked_capital: felt) {
    // Returns capital that is unlocked for immediate extraction/use.
    // This is for example ETH in case of ETH/USD CALL options.

    // Capital locked by the pool
    let (locked_capital) = pool_locked_capital.read();

    // Get capital that is sum of unlocked (available) and locked capital.
    let (contract_balance) = lpool_balance.read();

    let unlocked_capital = contract_balance - locked_capital;
    return (unlocked_capital = unlocked_capital);
}


func get_option_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_side: felt, maturity: felt, strike_price: felt
) -> (option_token_address: felt) {
    let (option_token_addr) = option_token_address.read(
        option_side, maturity, strike_price
    );
    return (option_token_address=option_token_addr);
}


func get_value_of_pool_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (value_of_position: Uint256) {
    // Returns a total value of pools position (sum of value of all options held by pool).
    // Goes through all options in storage var "available_options"... is able to iterate by i (from 0 to n)
    // It gets 0 from available_option(n), if the n-1 is the "last" option.
    // This could possibly use map from https://github.com/onlydustxyz/cairo-streams/
    // If this doesn't look "good", there is an option to have the available_options instead
    // of having the argument i, it could have no argument and return array (it might be easier for the map above)

    //FIXME 2: implement, for suggestion look at description 2-3 lines above
}


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


// @external
// func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(...):
// sets pair, liquidity currency and hence the option type
// for example pair is ETH/USDC and this pool is only for ETH hence only call options are handled here
// end

// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Provide/remove liquidity
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

// lptoken_amt * exchange_rate = underlying_amt
// @returns Math64x61 fp num
// func get_lptoken_exchange_rate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
//     pooled_token_addr: felt
// ) -> (exchange_rate: felt):
//     let (lpt_supply) = totalSupply()
//     let (own_addr) = get_contract_address()
//     let (reserves) = IERC20.balanceOf(contract_address=pooled_token_addr, account=own_addr)
//     let exchange_rate = Math64x61_div(lpt_supply, reserves)
//     return (exchange_rate)
// end


func get_lptokens_for_underlying{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt, underlying_amt: Uint256
) -> (lpt_amt: Uint256) {
    // Takes in underlying_amt in quote or base tokens (based on the pool being put/call).
    // Returns how much lp tokens correspond to capital of size underlying_amt

    alloc_locals;
    let (own_addr) = get_contract_address();

    let (free_capital) = get_unlocked_capital();
    let (value_of_position) = get_value_of_pool_position();
    let (value_of_pool) = uint256_add(free_capital, value_of_position);

    if (value_of_pool.low == 0) {
        return (underlying_amt,);
    }
    let (lpt_addr) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    let (lpt_supply) = ILPToken.totalSupply(contract_address=lpt_addr);
    let (quot, rem) = uint256_unsigned_div_rem(lpt_supply, value_of_pool);
    let (to_mint_low, to_mint_high) = uint256_mul(quot, underlying_amt);
    assert to_mint_high.low = 0;
    let (to_div_low, to_div_high) = uint256_mul(rem, underlying_amt);
    assert to_div_high.low = 0;
    let (to_mint_additional_quot, to_mint_additional_rem) = uint256_unsigned_div_rem(
        to_div_low, value_of_pool
    );  // to_mint_additional_rem goes to liq pool // treasury
    let (mint_total, carry) = uint256_add(to_mint_additional_quot, to_mint_low);
    assert carry = 0;
    return (mint_total,);
}

// computes what amt of underlying corresponds to a given amt of lpt.
// Doesn't take into account whether this underlying is actually free to be withdrawn.
// computes this essentially: my_underlying = (total_underlying/total_lpt)*my_lpt
// notation used: ... = (a)*my_lpt = b
func get_underlying_for_lptokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt, lpt_amt: Uint256
) -> (underlying_amt: Uint256) {
    // Takes in lpt_amt in terms of amount of lp tokens.
    // Returns how much underlying in quote or base tokens (based on the pool being put/call)
    // corresponds to given lp tokens.

    alloc_locals;

    let (lpt_addr: felt) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    let (total_lpt: Uint256) = ILPToken.totalSupply(contract_address=lpt_addr);

    let (free_capital) = get_unlocked_capital();
    let (value_of_position) = get_value_of_pool_position();
    let (total_underlying_amt) = uint256_add(free_capital, value_of_position);

    let (a_quot, a_rem) = uint256_unsigned_div_rem(total_underlying_amt, total_lpt);
    let (b_low, b_high) = uint256_mul(a_quot, lpt_amt);
    assert b_high.low = 0;  // bits that overflow uint256 after multiplication
    let (tmp_low, tmp_high) = uint256_mul(a_rem, lpt_amt);
    assert tmp_high.low = 0;
    let (to_burn_additional_quot, to_burn_additional_rem) = uint256_unsigned_div_rem(
        tmp_low, total_lpt
    );
    let (to_burn, carry) = uint256_add(to_burn_additional_quot, b_low);
    assert carry = 0;
    return (to_burn,);
}

// FIXME 4: add unittest that
// amount = get_underlying_for_lptokens(addr, get_lptokens_for_underlying(addr, amount))
//ie that what you get for lptoken is what you need to get same amount of lptokens


// Mints LPToken
// Assumes the underlying token is already approved (directly call approve() on the token being
// deposited to allow this contract to claim them)
// amt is amount of underlying token to deposit (either in base or quote based on call or put pool)
@external
func deposit_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt, amt: Uint256
) {
    let (caller_addr) = get_caller_address();
    let (own_addr) = get_contract_address();

    // Transfer tokens to pool.
    // We can do this optimistically;
    // any later exceptions revert the transaction anyway. saves some sanity checks
    IERC20.transferFrom(
        contract_address=pooled_token_addr, sender=caller_addr, recipient=own_addr, amount=amt
    );

    // update the lpool_balance by the provided capital
    let (current_balance) = lpool_balance.read(pooled_token_addr);
    let (new_pb: Uint256, carry: felt) = uint256_add(current_balance, amt);
    assert carry = 0;
    lpool_balance.write(pooled_token_addr, new_pb);

    // Calculates how many lp tokens will be minted for given amount of provided capital.
    let (mint_amt) = get_lptokens_for_underlying(pooled_token_addr, amt);
    // Transfers the capital
    let (lpt_addr) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    // Mint LP tokens
    ILPToken.mint(contract_address=lpt_addr, to=caller_addr, amount=mint_amt);
    return ();
}

@external
func withdraw_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt, lp_token_amount: Uint256
) {
    // lp_token_amount is in terms of lp tokens, not underlying as deposit_liquidity

    alloc_locals;
    let (caller_addr_) = get_caller_address();
    local caller_addr = caller_addr_;
    let (own_addr) = get_contract_address();

    // Get the amount of underlying that corresponds to given amount of lp tokens
    let (underlying_amount) = get_underlying_for_lptokens(pooled_token_addr, lp_token_amount);

    with_attr error_message(
        "Not enough 'cash' available funds in pool. Wait for it to be released from locked capital"
    ):
        let (free_capital) = get_unlocked_capital();
        assert_nn(free_capital - underlying_amount);
    end

    // Transfer underlying (base or quote depending on call/put)
    // We can do this transfer optimistically;
    // any later exceptions revert the transaction anyway. saves some sanity checks
    IERC20.transferFrom(
        contract_address=pooled_token_addr,
        sender=own_addr,
        recipient=caller_addr,
        amount=underlying_amount
    );

    // Burn LP tokens
    let (lpt_addr) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    ILPToken.burn(contract_address=lpt_addr, account=caller_addr, amount=lp_token_amount);

    // Update that the capital in the pool (including the locked capital).
    let (current_balance: Uint256) = lpool_balance.read(pooled_token_addr);
    let (new_pb: Uint256) = uint256_sub(current_balance, underlying_amount);
    lpool_balance.write(pooled_token_addr, new_pb);

    return ();
}


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Trade options
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #



// User increases its position (if user is long, it increases the size of its long,
// if he/she is short, the short gets increased).
// Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
// This corresponds to something like "mint_option_token", but does more, it also changes internal state of the pool
//   and realocates locked capital/premia and fees between user and the pool
//   for example how much capital is unlocked, how much is locked,...
func mint_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_size: felt,
    option_size_in_pool_currency: felt,
    option_side: felt,
    option_type: felt,
    maturity: felt,
    strike_price: felt,
    premia_including_fees: felt,
    underlying_price: felt,
) {
    // currency_address: felt,  // adress of token staked in the pool (ETH/USDC/...)
    // option_size: felt,  // same as option_size... in base tokens (ETH in case of ETH/USDC)
    // option_side: felt,
    // option_type: felt,
    // maturity: felt,  // felt in seconds
    // strike: felt,  // in Math64x61
    // premia_including_fees: felt,  // in Math64x61 in either base or quote token
    // underlying_price: felt, // in Math64x61

    alloc_locals;

    let (currency_address) = underlying_token_addres.read(option_type);
    let (option_token_address) = get_option_token_address(
        option_side=side,
        maturity=maturity,
        strike_price=strike_price
    );

    // Make sure the contract is the one that user wishes to trade
    let (contract_option_type) = IOptionToken.option_type(option_token_address);
    let (contract_strike) = IOptionToken.strike(option_token_address);
    let (contract_maturity) = IOptionToken.maturity(option_token_address);
    let (contract_option_side) = IOptionToken.side(option_token_address);

    with_attr error_message("Required contract doesn't match the address.") {
        assert contract_option_type = option_type;
        assert contract_strike = strike_price;
        assert contract_maturity = maturity;
        assert contract_option_side = option_side;
    }

    if (option_side == TRADE_SIDE_LONG) {
        _mint_option_token_long(
            currency_address=currency_address,
            option_token_address=option_token_address,
            option_size=option_size,
            option_size_in_pool_currency=option_size_in_pool_currency,
            premia_including_fees=premia_including_fees,
            option_type=option_type,
            strike_price=strike_price,
        );
    } else {
        _mint_option_token_short(
            currency_address=currency_address,
            option_token_address=option_token_address,
            option_size=option_size,
            option_size_in_pool_currency=option_size_in_pool_currency,
            premia_including_fees=premia_including_fees,
            option_type=option_type,
            maturity=maturity,
            strike_price=strike_price,
            underlying_price=underlying_price,
        );
    }

    return ();
}

func _mint_option_token_long{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token_address: felt,
    option_size: felt,
    option_size_in_pool_currency: felt,
    premia_including_fees: felt,
    option_type: felt,
    strike_price: felt,
) {
    alloc_locals;

    let (current_contract_address) = get_contract_address();
    let (user_address) = get_caller_address();
    let (currency_address) = underlying_token_addres.read(option_type);

    // Mint tokens
    IOptionToken.mint(option_token_address, user_address, option_size);

    // Move premia and fees from user to the pool
    IERC20.transferFrom(
        contract_address=currency_address,
        sender=user_address,
        recipient=current_contract_address,
        amount=premia_including_fees,
    );  // Transaction will fail if there is not enough fund on users account

    // Pool is locking in capital inly if there is no previous position to cover the user's long
    //      -> if pool does not have sufficient long to "pass down to user", it has to lock
    //           capital... option position has to be updated too!!!

    // Increase lpool_balance by premia_including_fees -> this also increases unlocked capital
    // since only locked_capital storage_var exists
    let (current_balance) = lpool_balance.read();
    let (new_balance) = current_balance + premia_including_fees;
    lpool_balance.write(new_balance);

    // Update pool's position, lock capital... lpool_balance was already updated above
    let (current_long_position) = option_position.read(TRADE_SIDE_LONG, maturity, strike_price);
    let (current_short_position) = option_position.read(TRADE_SIDE_SHORT, maturity, strike_price);
    let (current_locked_balance) = pool_locked_capital.read();

    // Get diffs to update everything
    let (decrease_long_by) = min(option_size, current_long_position);
    let (increase_short_by) = option_size - decrease_long_by;
    let (increase_locked_by) = convert_amount_to_option_currency_from_base(increase_short_by, option_type, strike_price);

    // New state
    let (new_long_position) = current_long_position - decrease_long_by;
    let (new_short_position) = current_short_position + increase_short_by;
    let (new_locked_capital) = current_locked_balance + increase_locked_by;

    // Check that there is enough capital to be locked.
    with_attr error_message("Not enough unlocked capital in pool") {
        assert_nn(new_balance - pool_locked_capital);
    }

    // Update the state
    option_position.write(TRADE_SIDE_LONG, maturity, strike_price, new_long_position);
    option_position.write(TRADE_SIDE_SHORT, maturity, strike_price, new_short_position);
    pool_locked_capital.write(new_locked_capital);

    return ();
}

func _mint_option_token_short{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token_address: felt,
    option_size: felt,
    option_size_in_pool_currency: felt,
    premia_including_fees: felt,
    option_type: felt,
    maturity: felt,
    strike_price: felt,
    underlying_price: felt,
) {
    alloc_locals;

    let (current_contract_address) = get_contract_address();
    let (user_address) = get_caller_address();
    let (currency_address) = underlying_token_addres.read(option_token);

    // Mint tokens
    IOptionToken.mint(option_token_address, user_address, option_size);

    let to_be_paid_by_user = option_size_in_pool_currency - premia_including_fees;

    // Move (option_size minus (premia minus fees)) from user to the pool
    IERC20.transferFrom(
        contract_address=currency_address,
        sender=user_address,
        recipient=current_contract_address,
        amount=to_be_paid_by_user,
    );
    
    // Decrease lpool_balance by premia_including_fees -> this also decreases unlocked capital
    // since only locked_capital storage_var exists
    let (current_balance) = lpool_balance.read();
    let (new_balance) = current_balance - premia_including_fees;
    lpool_balance.write(new_balance)

    // User is going short, hence user is locking in capital...
    //       if pool has short position -> unlock pool's capital
    // pools_position is in terms of base tokens (ETH in case of ETH/USD)... in same units is option_size
    // since user wants to go short, the pool can "sell off" its short... and unlock its capital

    // Update pool's short position
    let (pools_short_position) = option_position.read(TRADE_SIDE_SHORT, maturity, strike_price);
    let (size_to_be_unlocked_in_base) = min(option_size, pools_position);
    let (new_pools_short_position) = pools_short_position - size_to_be_unlocked_in_base;
    option_position.write(TRADE_SIDE_SHORT, maturity, strike_price, new_pools_short_position);

    // Update pool's long position
    let (pools_long_position) = option_position.read(TRADE_SIDE_LONG, maturity, strike_price);
    let (size_to_increase_long_position) = option_size - size_to_be_unlocked_in_base;
    let (new_pools_long_position) = pools_long_position + size_to_increase_long_position;
    option_position.write(TRADE_SIDE_LONG, maturity, strike_price, new_pools_long_position);

    // Update the locked capital
    let (size_to_be_unlocked) = convert_amount_to_option_currency_from_base(size_to_be_unlocked_in_base, option_type, strike_price);
    let (current_locked_balance) = pool_locked_capital.read();
    let new_locked_balance = current_locked_balance - size_to_be_unlocked;

    with_attr error_message("Not enough capital") {
        // This will never happen. It is here just as sanity check.
        assert_nn(new_locked_balance);
    }
       
    pool_locked_capital.write(new_locked_balance);

    return ();
}

// User decreases its position (if user is long, it decreases the size of its long,
// if he/she is short, the short gets decreased).
// Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
// This corresponds to something like "burn_option_token", but does more, it also changes internal state of the pool
//   and realocates locked capital/premia and fees between user and the pool
//   for example how much capital is unlocked, how much is locked,...
func burn_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_size: felt,
    option_size_in_pool_currency: felt,
    option_side: felt,
    option_type: felt,
    maturity: felt,
    strike_price: felt,
    premia_including_fees: felt,
    underlying_price: felt,
) {
    // option_side is the side of the token being closed

    alloc_locals;

    let (option_token_address) = get_option_token_address(
        option_side=side,
        maturity=maturity,
        strike_price=strike_price
    );

    // Make sure the contract is the one that user wishes to trade
    let (contract_option_type) = IOptionToken.option_type(option_token_address);
    let (contract_strike) = IOptionToken.strike(option_token_address);
    let (contract_maturity) = IOptionToken.maturity(option_token_address);
    let (contract_option_side) = IOptionToken.side(option_token_address);

    with_attr error_message("Required contract doesnt match the address.") {
        assert contract_option_type = option_type;
        assert contract_strike = strike_price;
        assert contract_maturity = maturity;
        assert contract_option_side = option_side;
    }

    if (option_side == TRADE_SIDE_LONG) {
        _burn_option_token_long(
            currency_address=currency_address,
            option_token_address=option_token_address,
            option_size=option_size,
            option_size_in_pool_currency=option_size_in_pool_currency,
            premia_including_fees=premia_including_fees,
            option_side = option_side,
            option_type=option_type,
            maturity = maturity,
            strike_price=strike_price,
        );
    } else {
        _burn_option_token_short(
            currency_address=currency_address,
            option_token_address=option_token_address,
            option_size=option_size,
            option_size_in_pool_currency=option_size_in_pool_currency,
            premia_including_fees=premia_including_fees,
            option_side=option_size,
            option_type=option_type,
            maturity=maturity,
            strike_price=strike_price,
        );
    }
    return ();
}

func _burn_option_token_long{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token_address: felt,
    option_size: felt,
    option_size_in_pool_currency: felt,
    premia_including_fees: felt,
    option_side: felt,
    option_type: felt,
    maturity: felt,
    strike_price: felt,
) {
    // option_side is the side of the token being closed
    // user is closing its long position -> freeing up pool's locked capital
    // (but only if pool is short, otherwise the locked capital was covered by other user)

    alloc_locals;

    let (current_contract_address) = get_contract_address();
    let (user_address) = get_caller_address();
    let (currency_address) = underlying_token_addres.read(option_type);
    
    // Burn the tokens
    IOptionToken.burn(option_token_address, user_address, option_size);

    IERC20.transferFrom(
        contract_address=currency_address,
        sender=current_contract_address,
        recipient=user_address,
        amount=premia_including_fees,
    );

    let (current_pool_position) = option_position.read(
        option_side,
        maturity,
        strike_price
    );

    // Decrease lpool_balance by premia_including_fees -> this also decreases unlocked capital
    // This decrease is happening because burning long is similar to minting short, hence the payment.
    // since only locked_capital storage_var exists
    let (current_balance) = lpool_balance.read();
    let (new_balance) = current_balance - premia_including_fees;
    lpool_balance.write(new_balance)

    let (pool_short_position) = option_position.read(
        TRADE_SIDE_SHORT,
        maturity,
        strike_price
    );

    if (pool_short_position = 0){
        // If pool is LONG:
        // Burn long increases pool's long (if pool was already long)
        //      -> The locked capital was locked by users and not pool
        //      -> do not decrease pool_locked_capital by the option_size_in_pool_currency
        let new_option_position = current_pool_position + option_size;
        option_position.write(
            option_side,
            maturity,
            strike_price,
            new_option_position
        );
    } else {
        // If pool is SHORT
        // Burn decreases the pool's short
        //     -> decrease the pool_locked_capital by min(size of pools short, amount_in_pool_currency)
        //         since the pools' short might not be covering all of the long

        // Update the locked capital
        let (current_locked_balance) = pool_locked_capital.read();
        let (size_to_be_unlocked_in_base) = min(current_pool_position, option_size);
        let (size_to_be_unlocked) = convert_amount_to_option_currency_from_base(size_to_be_unlocked_in_base, option_type, strike_price);
        let (new_locked_balance) = current_locked_balance - size_to_be_unlocked;
        pool_locked_capital.write(new_locked_balance);

        // Update pool's short position
        let (pools_short_position) = option_position.read(TRADE_SIDE_SHORT, maturity, strike_price);
        let (new_pools_short_position) = pools_short_position - size_to_be_unlocked_in_base;
        option_position.write(TRADE_SIDE_SHORT, maturity, strike_price, new_pools_short_position);

        // Update pool's long position
        let (pools_long_position) = option_position.read(TRADE_SIDE_LONG, maturity, strike_price);
        let (size_to_increase_long_position) = option_size - size_to_be_unlocked_in_base;
        let (new_pools_long_position) = pools_long_position + size_to_increase_long_position;
        option_position.write(TRADE_SIDE_LONG, maturity, strike_price, new_pools_long_position);
    }
    return ();
}

func _burn_option_token_short{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token_address: felt,
    option_size: felt,
    option_size_in_pool_currency: felt,
    premia_including_fees: felt,
    option_side: felt,
    option_type: felt,
    maturity: felt,
    strike_price: felt,
) {
    // option_side is the side of the token being closed

    alloc_locals;

    let (current_contract_address) = get_contract_address();
    let (user_address) = get_caller_address();
    let (currency_address) = underlying_token_addres.read(option_type);

    // Burn the tokens
    IOptionToken.burn(option_token_address, user_address, option_size);

    // User receives back its locked capital, pays premia and fees
    let total_user_payment = option_size_in_pool_currency - premia_including_fees;
    IERC20.transferFrom(
        contract_address=currency_address,
        sender=current_contract_address,
        recipient=user_address,
        amount=total_user_payment,
    );

    // Increase lpool_balance by premia_including_fees -> this also increases unlocked capital
    // This increase is happening because burning short is similar to minting long, hence the payment.
    // since only locked_capital storage_var exists
    let (current_balance) = lpool_balance.read();
    let (new_balance) = current_balance + premia_including_fees;
    lpool_balance.write(new_balance);

    // Find out pools position... if it has short position = 0 -> it is long or at 0
    let (pool_short_position) = option_position.read(TRADE_SIDE_SHORT, maturity, strike_price);

    // FIXME: the inside of the if (not the else) should work for both cases
    if (pool_short_position = 0) {
        // If pool is LONG
        // Burn decreases pool's long -> up to a size of the pool's long 
        //      -> if option_size_in_pool_currency > pool's long -> pool starts to accumulate the short and 
        //         has to lock in it's own capital -> lock capital
        //      -> there might be a case, when there is not enough capital to be locked -> fail the transaction

        let (pool_long_position) = option_position.read(TRADE_SIDE_LONG, maturity, strike_price);

        let (decrease_long_position_by) = min(pool_long_position, option_size);
        let (increase_short_position_by) = option_size - decrease_long_position_by;
        let (new_long_position) = pool_long_position - decrease_long_position_by;
        let (new_short_position) = pool_short_position + increase_short_position_by;

        // The increase_short_position_by and capital_to_be_locked might both be zero,
        // if the long position is sufficient.
        let (capital_to_be_locked) = convert_amount_to_option_currency_from_base(
            increase_short_position_by,
            option_type,
            strike_price
        );
        let (current_locked_capital) = pool_locked_capital.read();
        let (new_locked_capital) = current_locked_capital + capital_to_be_locked;

        // Set the option positions
        option_position.write(TRADE_SIDE_LONG, maturity, strike_price, new_long_position);
        option_position.write(TRADE_SIDE_SHORT, maturity, strike_price, new_short_position);

        // Set the pool_locked_capital.
        pool_locked_capital.write(new_locked_capital);

        // Assert there is enough capital to be locked
        with_attr error_message("Not enough capital to be locked.") {
            assert_nn(new_balance - new_locked_capital);
        }

    } else {
        // If pool is SHORT
        // Burn increases pool's short
        //      -> increase pool's locked capital by the option_size_in_pool_currency
        //      -> there might not be enough unlocked capital to be locked
        let (current_locked_capital) = pool_locked_capital.read();
        let (current_total_capital) = lpool_balance.read();
        let current_unlocked_capital  = current_total_capital - current_locked_capital;

        with_attr error_message("Not enough unlocked capital."){
            assert_nn(current_unlocked_capital - option_size_in_pool_currency);
        }

        // Update locked capital
        let new_locked_capital = current_locked_capital + option_size_in_pool_currency;
        pool_locked_capital.write(new_locked_capital);

        // Update pools (short) position
        let (pools_short_position) = option_position.read(TRADE_SIDE_SHORT, maturity, strike_price);
        let (new_pools_short_position) = pools_short_position - option_size;
        option_position.write(TRADE_SIDE_SHORT, maturity, strike_price, new_pools_short_position);
    }

    return ();
}


func expire_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt,
    option_side: felt,
    strike_price: felt,
    terminal_price: felt, 
    option_size: felt,
    maturity: felt,
) {
    // EXPIRES OPTIONS ONLY FOR USERS (OPTION TOKEN HOLDERS) NOT FOR POOL.
    // terminal price is price at which option is being settled

    alloc_locals;

    let (option_token_address) = get_option_token_address(
        option_side=side,
        maturity=maturity,
        strike_price=strike_price
    );

    let (currency_address) = underlying_token_addres.read(option_type);

    // The option (underlying asset x maturity x option type x strike) has to be "expired"
    // (settled) on the pool's side in terms of locked capital. Ie check that SHORT position
    // has been settled, if pool is LONG then it did not lock capital and we can go on.
    let (current_pool_position) = option_position.read(TRADE_SIDE_SHORT, maturity, strike_price);
    with_attr error_message("Pool hasn't released the locked capital for users -> call expire_option_token_for_pool to release it.") {
        // Even though the transaction might go through with no problems, there is a chance
        // of it failing or chance for pool manipulation.
        assert current_pool_position = 0;
    }

    // Make sure the contract is the one that user wishes to expire
    let (contract_option_type) = IOptionToken.option_type(option_token_address);
    let (contract_strike) = IOptionToken.strike(option_token_address);
    let (contract_maturity) = IOptionToken.maturity(option_token_address);
    let (contract_option_side) = IOptionToken.side(option_token_address);
    let (current_contract_address) = get_contract_address();

    with_attr error_message("Required contract doesn't match the address.") {
        assert contract_option_type = option_type;
        assert contract_strike = strike_price;
        assert contract_maturity = maturity;
        assert contract_option_side = option_side;
    }

    // Make sure that user owns the option tokens
    let (user_address) = get_caller_address();
    let (user_tokens_owned) = IOptionToken.balanceOf(
        contract_address=current_contract_address, account=user_address
    );
    with_attr error_message("User doesn't own any tokens.") {
        assert_nn(user_tokens_owned);
    }

    // Make sure that the contract is ready to expire
    let (current_block_time) = get_block_timestamp();
    let (is_ripe) = is_le(maturity, current_block_time);
    with_attr error_message("Contract isn't ripe yet.") {
        assert is_ripe = 1;
    }

    // long_value and short_value are both in terms of locked capital
    let (long_value, short_value) = split_option_locked_capital(
        option_type, option_side, option_size, strike_price, terminal_price
    );

    if (option_side == TRADE_SIDE_LONG) {
        // User is long
        // When user was long there is a possibility, that the pool is short,
        // which means that pool has locked in some capital.
        // We assume pool is able to "expire" it's functions pretty quickly so the updates
        // of storage_vars has already happened.
        IERC20.transferFrom(
            contract_address=currency_address,
            sender=current_contract_address,
            recipient=user_address,
            amount=long_value,
        );
    } else {
        // User is short
        // User locked in capital (no locking happened from pool - no locked capital and similar
        // storage vars were updated).
        IERC20.transferFrom(
            contract_address=currency_address,
            sender=current_contract_address,
            recipient=user_address,
            amount=short_value,
        );
    }

    return ();
}


func adjust_capital_for_pools_expired_options{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    long_value: felt,
    short_value: felt,
    option_size: felt,
    option_side: felt,
    maturity: felt,
    strike_price: felt
) {
    // This function is a helper function used only for expiring POOL'S options.
    // option_side is from perspektive of the pool

    alloc_locals

    // lpool_balance is total staked capital which has to be decreased by the "opposite" of adjust_by...

    let (current_lpool_balance) = lpool_balance.read();
    let (current_locked_balance) = pool_locked_capital.read();
    let (current_pool_position) = option_position.read(option_side, maturity, strike_price);

    let (new_pool_position) = current_pool_position - option_size
    option_position.write(option_side, maturity, strike_price, new_pool_position);

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

        let new_lpool_balance = current_lpool_balance + long_value;
        lpool_balance.write(pooled_token_addr, new_lpool_balance);
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

        let new_lpool_balance = current_lpool_balance - long_value;
        let new_locked_balance = current_locked_balance - short_value - long_value;

        with_attr error_message("Not enough capital in the pool") {
            // This will never happen since the capital to pay the users is always locked.
            assert_nn(new_lpool_balance);
            assert_nn(new_locked_balance);
        }

        lpool_balance.write(pooled_token_addr, new_lpool_balance);
        pool_locked_capital.write(new_lpool_balance);
    }
    return ();
}


func split_option_locked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt,
    option_side: felt,
    option_size: felt,
    strike_price: felt,
    terminal_price: felt, // terminal price is price at which option is being settled
) -> (long_value: felt, short_value: felt) {
    alloc_locals;

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    if (option_type == OPTION_CALL) {
        // User receives max(0, option_size * (terminal_price - strike_price) / terminal_price) in base token for long
        // User receives (option_size - long_profit) for short
        let price_diff = terminal_price - strike_price;
        let to_be_paid_quote = option_size * price_diff;
        let to_be_paid_base = to_be_paid / terminal_price;
        let to_be_paid_buyer = max(0, to_be_paid_base);
        let to_be_paid_seller = option_size - to_be_paid_buyer;

        return (to_be_paid_buyer, to_be_paid_seller);
    }

    // For Put option
    // User receives  max(0, option_size * (strike_price - terminal_price)) in base token for long
    // User receives (option_size * strike_price - long_profit) for short
    let price_diff = strike_price - terminal_price;
    let amount_x_diff_quote = option_size * price_diff;
    let to_be_paid_buyer = max(0, amount_x_diff_quote);
    let to_be_paid_seller = option_size * strike_price - to_be_paid_buyer;

    return (to_be_paid_buyer, to_be_paid_seller);
}


@external
func expire_option_token_for_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_side: felt,
    strike_price: felt,
    maturity: felt,
) {

    alloc_locals;

    let (option_type) = option_type_.read();

    // pool's position... has to be nonnegative since the position is per side (long/short)
    let (option_size) = option_position.read(option_side, maturity, strike_price);
    assert_nn(option_size);
    if (option_size == 0){
        // Pool's position is zero, there is nothing to expire.
        // This also checks that the option exists (if it doesn't storage_var returns 0).
        return ();
    }
    // From now on we know that pool's position is positive -> option_size > 0.

    // Make sure the contract is ready to expire
    let (current_block_time) = get_block_timestamp();
    let (is_ripe) = is_le(maturity, current_block_time);
    with_attr error_message("Contract isn't mature yet") {
        assert is_ripe = 1;
    }

    // Get terminal price of the option.
    let (terminal_price) = FIXME 12;

    let (long_value, short_value)  = split_option_locked_capital(
        option_type, option_side, option_size, strike_price, terminal_price
    );

    adjust_capital_for_pools_expired_options(
        long_value=long_value,
        short_value=short_value,
        option_size=option_size,
        option_side=option_side,
        maturity=maturity,
        strike_price=strike_price
    );

    return ();
}
