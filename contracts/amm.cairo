# Internals of the AMM

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
# from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_nn_le, assert_nn
# from starkware.cairo.common.math import assert_le, unsigned_div_rem
from starkware.starknet.common.syscalls import get_block_timestamp  # storage_write
from contracts.Math64x61 import (
    Math64x61_fromFelt,
    Math64x61_mul,
    Math64x61_div,
    Math64x61_add,
    Math64x61_sub,
    Math64x61_min,
    Math64x61_ONE,
)

from contracts.constants import (
    POOL_BALANCE_UPPER_BOUND,
    ACCOUNT_BALANCE_UPPER_BOUND,
    VOLATILITY_LOWER_BOUND,
    VOLATILITY_UPPER_BOUND,
    TOKEN_A,
    TOKEN_B,
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    TRADE_SIDE_SHORT,
    get_opposite_side,
    STRIKE_PRICE_UPPER_BOUND,
)
from contracts.fees import get_fees
from contracts.option_pricing import black_scholes
from contracts.oracles import empiric_median_price
from contracts._cfg import EMPIRIC_ETH_USD_KEY

# FIXME: look into how the token sizes are dealt with across different protocols
# A map from account and token type to the corresponding balance of that account in given pool.
# Ie this describes how much of the given pool the given account owns.
@storage_var
func account_balance(account_id : felt, token_type : felt) -> (balance : felt):
end

# A map from option type to the corresponding balance of the pool.
@storage_var
func pool_balance(option_type : felt) -> (balance : felt):
end

# Stores information about underwritten or bought options that the AMM could
# use instead of minting a new option. If balance > 0 -> pool does not have to
# mint new options if user wants to buy, balance < 0 means the same when
# user wants to sell.
@storage_var
func pool_option_balance(option_type : felt, strike_price : felt, maturity : felt, side : felt) -> (
    balance : felt
):
end

# Stores current value of volatility for given pool (option type) and maturity.
@storage_var
func pool_volatility(option_type : felt, maturity : felt) -> (volatility : felt):
end

# Determines whether an option is allowed or not. If 1 is returned, option is allowed.
# FIXME: is this a good design?
@storage_var
func available_options(option_type : felt, strike_price : felt, maturity : felt) -> (
    availability : felt
):
end

# ---------------storage_var handlers------------------

func set_pool_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt, balance : felt
):
    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0
    assert_nn_le(balance, POOL_BALANCE_UPPER_BOUND - 1)
    pool_balance.write(option_type, balance)
    return ()
end

func set_account_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt, token_type : felt, balance : felt
):
    assert (token_type - TOKEN_A) * (token_type - TOKEN_B) = 0
    assert_nn_le(balance, POOL_BALANCE_UPPER_BOUND - 1)
    account_balance.write(account_id, token_type, balance)
    return ()
end

func set_pool_option_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt, strike_price : felt, maturity : felt, side : felt, balance : felt
):
    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0
    assert (side - TRADE_SIDE_LONG) * (side - TRADE_SIDE_SHORT) = 0
    assert_nn_le(balance, POOL_BALANCE_UPPER_BOUND - 1)
    # FIXME: assert maturity
    # FIXME: assert side

    pool_option_balance.write(option_type, strike_price, maturity, side, balance)
    return ()
end

func set_pool_volatility{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt, maturity : felt, volatility : felt
):
    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0
    assert_nn_le(volatility, VOLATILITY_UPPER_BOUND - 1)
    assert_nn_le(VOLATILITY_LOWER_BOUND, volatility)  # TODO why? vol - 1
    pool_volatility.write(option_type, maturity, volatility)
    return ()
end

func set_available_options{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt, strike_price : felt, maturity : felt
):
    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0
    # FIXME: assert that maturity > current time
    assert_nn_le(strike_price, STRIKE_PRICE_UPPER_BOUND - 1)

    # Sets the availability of option to 1 (True)
    available_options.write(option_type, strike_price, maturity, 1)
    return ()
end

@view
func get_pool_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt
) -> (pool_balance : felt):
    let (pool_balance_) = pool_balance.read(option_type)
    return (pool_balance_)
end

@view
func get_account_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt, token_type : felt
) -> (account_balance : felt):
    let (account_balance_) = account_balance.read(account_id, token_type)
    return (account_balance_)
end

@view
func get_pool_option_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt, strike_price : felt, maturity : felt, side : felt
) -> (pool_option_balance : felt):
    let (pool_option_balance_) = pool_option_balance.read(option_type, strike_price, maturity, side)
    return (pool_option_balance_)
end

@view
func get_pool_volatility{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt, maturity : felt
) -> (pool_volatility : felt):
    let (pool_volatility_) = pool_volatility.read(option_type, maturity)
    return (pool_volatility_)
end

@view
func get_available_options{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt, strike_price : felt, maturity : felt
) -> (option_availability : felt):
    let (option_availability_) = available_options.read(option_type, strike_price, maturity)
    return (option_availability_)
end

# ---------------AMM logic------------------

func _select_and_adjust_premia{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    call_premia : felt, put_premia : felt, option_type : felt, underlying_price : felt
) -> (premia : felt):
    # Call and put premia are in quote tokens (in USDC in case of ETH/USDC)

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0

    if option_type == OPTION_CALL:
        let (adjusted_call_premia) = Math64x61_div(call_premia, underlying_price)
        return (premia=adjusted_call_premia)
    end
    return (premia=put_premia)
end

func _calc_new_pool_balance_with_premia{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(side : felt, current_pool_balance : felt, total_premia : felt) -> (pool_balance : felt):
    if side == TRADE_SIDE_LONG:
        # User goes long and pays premia to the pool_balance
        let (long_pool_balance) = Math64x61_add(current_pool_balance, total_premia)
        return (long_pool_balance)
    end
    # User goes short and pool pays premia to the user
    let (short_pool_balance) = Math64x61_sub(current_pool_balance, total_premia)
    return (short_pool_balance)
end

func _time_till_maturity{syscall_ptr : felt*, range_check_ptr}(maturity : felt) -> (
    time_till_maturity : felt
):
    alloc_locals
    local syscall_ptr : felt* = syscall_ptr  # Reference revoked fix

    let (currtime) = get_block_timestamp()  # is number of seconds... unix timestamp
    let (currtime_math) = Math64x61_fromFelt(currtime)
    let (maturity_math) = Math64x61_fromFelt(maturity)
    let (secs_in_year) = Math64x61_fromFelt(60 * 60 * 24 * 365)

    let (secs_left) = Math64x61_sub(maturity_math, currtime_math)
    assert_nn(secs_left)

    let (time_till_maturity) = Math64x61_div(secs_left, secs_in_year)
    return (time_till_maturity)
end

func _calc_new_pool_balance_with_locked_capital{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(
    side : felt,
    option_type : felt,
    current_pool_balance : felt,
    underlying_price : felt,
    to_be_traded : felt,
    to_be_minted : felt,
) -> (pool_balance : felt):
    # if side==TRADE_SIDE_SHORT increase pool_balance by
    # if option_type==OPTION_CALL increase (call pool) it by to_be_traded
    # if option_type==OPTION_PUT increase (put pool) it by to_be_traded*underlying_price
    # if side==TRADE_SIDE_LONG decrease pool_balance by
    # if option_type==OPTION_CALL decrease it by to_be_minted
    # if option_type==OPTION_PUT decrease it by to_be_minted*underlying_price

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0
    assert (side - TRADE_SIDE_SHORT) * (side - TRADE_SIDE_LONG) = 0

    if side == TRADE_SIDE_SHORT:
        if option_type == OPTION_CALL:
            let (to_be_traded_call_short) = Math64x61_add(current_pool_balance, to_be_traded)
            return (to_be_traded_call_short)
        end
        let (to_be_traded_put) = Math64x61_mul(to_be_traded, underlying_price)
        let (to_be_traded_put_short) = Math64x61_add(current_pool_balance, to_be_traded_put)
        return (to_be_traded_put_short)
    end
    # here the side = TRADE_SIDE_LONG
    if option_type == OPTION_CALL:
        assert_nn_le(to_be_minted, current_pool_balance - 1)
        let (to_be_minted_call_long) = Math64x61_sub(current_pool_balance, to_be_minted)
        return (to_be_minted_call_long)
    end
    let (to_be_minted_put) = Math64x61_mul(to_be_minted, underlying_price)
    assert_nn_le(to_be_minted_put, current_pool_balance - 1)
    let (to_be_minted_put_long) = Math64x61_sub(current_pool_balance, to_be_minted_put)
    return (to_be_minted_put_long)
end

func _add_premia_fees{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    side : felt, total_premia_before_fees : felt, total_fees : felt
) -> (total_premia : felt):
    assert (side - TRADE_SIDE_SHORT) * (side - TRADE_SIDE_LONG) = 0

    # if side == TRADE_SIDE_LONG (user pays premia) the fees are added on top of premia
    # if side == TRADE_SIDE_SHORT (user receives premia) the fees are subtracted from the premia
    if side == TRADE_SIDE_LONG:
        let (premia_fees_add) = Math64x61_add(total_premia_before_fees, total_fees)
        return (premia_fees_add)
    end
    let (premia_fees_sub) = Math64x61_sub(total_premia_before_fees, total_fees)
    return (premia_fees_sub)
end

func _get_vol_update_denominator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    relative_option_size : felt, side : felt
) -> (relative_option_size : felt):
    if side == TRADE_SIDE_LONG:
        let (long_denominator) = Math64x61_sub(Math64x61_ONE, relative_option_size)
        return (long_denominator)
    end
    let (short_denominator) = Math64x61_add(Math64x61_ONE, relative_option_size)
    return (short_denominator)
end

func _get_new_volatility{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    current_volatility : felt, option_size : felt, option_type : felt, side : felt
) -> (new_volatility : felt, trade_volatility : felt):
    alloc_locals

    let (current_pool_balance) = get_pool_balance(option_type)
    assert_nn_le(Math64x61_ONE, current_pool_balance)
    assert_nn_le(option_size, current_pool_balance)
    let (relative_option_size) = Math64x61_div(option_size, current_pool_balance)

    # alpha – rate of change assumed to be 1
    let (denominator) = _get_vol_update_denominator(relative_option_size, side)
    let (volatility_scale) = Math64x61_div(Math64x61_ONE, denominator)
    let (new_volatility) = Math64x61_mul(current_volatility, volatility_scale)

    let (volsum) = Math64x61_add(current_volatility, new_volatility)
    let (two) = Math64x61_fromFelt(2)
    let (trade_volatility) = Math64x61_div(volsum, two)

    return (new_volatility=new_volatility, trade_volatility=trade_volatility)
end

func do_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt,
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    option_size : felt,
) -> (premia : felt):
    # options_size is always denominated in base tokens (ETH in case of ETH/USDC)

    alloc_locals

    # 0) Get current volatility
    let (current_volatility) = get_pool_volatility(option_type, maturity)

    # 1) Calculate new volatility, calculate trade volatility
    let (new_volatility, trade_volatility) = _get_new_volatility(
        current_volatility, option_size, option_type, side
    )

    # 2) Update volatility
    set_pool_volatility(option_type, maturity, new_volatility)

    # 3) Get price of underlying asset
    # Hardcode ETH for now
    let (underlying_price) = empiric_median_price(EMPIRIC_ETH_USD_KEY)

    # 4) Get time till maturity
    let (time_till_maturity) = _time_till_maturity(maturity)

    # 5) risk free rate
    let (three) = Math64x61_fromFelt(3)
    let (hundred) = Math64x61_fromFelt(100)
    # let (risk_free_rate_annualized) = Math64x61_div(three, hundred)
    let (risk_free_rate_annualized) = Math64x61_fromFelt(0)

    # 6) Get premia
    let (call_premia, put_premia) = black_scholes(
        sigma=trade_volatility,
        time_till_maturity_annualized=time_till_maturity,
        strike_price=strike_price,
        underlying_price=underlying_price,
        risk_free_rate_annualized=risk_free_rate_annualized,
    )
    # AFTER THE LINE BELOW, THE PREMIA IS IN TERMS OF CORRESPONDING POOL
    # Ie in case of call option, the premia is in base (ETH in case ETH/USDC)
    # and in quote tokens (USDC in case of ETH/USDC) for put option.
    let (premia) = _select_and_adjust_premia(call_premia, put_premia, option_type, underlying_price)
    # premia adjusted by size (multiplied by size)
    let (total_premia_before_fees) = Math64x61_mul(premia, option_size)

    # 7) Get fees
    # fees are already in the currency same as premia
    # if side == TRADE_SIDE_LONG (user pays premia) the fees are added on top of premia
    # if side == TRADE_SIDE_SHORT (user receives premia) the fees are substracted from the premia
    let (total_fees) = get_fees(total_premia_before_fees)
    let (total_premia) = _add_premia_fees(side, total_premia_before_fees, total_fees)

    # 1) Update the pool_balance
    # increase by the amount of fees (in corresponding TOKEN)
    # if side==TRADE_SIDE_LONG increase pool_balance by premia (in corresponding TOKEN)
    # if side==TRADE_SIDE_SHORT decrease pool_balance by premia (in corresponding TOKEN)
    let (current_pool_balance) = get_pool_balance(option_type)

    let (new_pool_balance) = _calc_new_pool_balance_with_premia(
        side, current_pool_balance, total_premia
    )
    # FIXME: the set_pool_balance is called here and below, this could be done only once
    set_pool_balance(option_type, new_pool_balance)

    # 2) get size of options that could be "traded" and not "minted" from pool_option_balance
    # if there are available ones, trade them, if not mint new ones
    # (could be partially traded and partially minted).
    let (available_option_balance) = get_pool_option_balance(
        option_type, strike_price, maturity, side
    )
    # option balance for opposite side
    let (opposite_side) = get_opposite_side(side)
    let (available_opposite_option_balance) = get_pool_option_balance(
        option_type, strike_price, maturity, opposite_side
    )
    # size of option and hence the available_option_balance is always in terms of base token
    # (ETH in case of ETH/USDC)

    # available_option_balance is always >= 0
    let (to_be_traded) = Math64x61_min(available_option_balance, option_size)
    let (to_be_minted) = Math64x61_sub(option_size, to_be_traded)

    # 3) Update the pool_option_balance
    # decrease by to_be_traded (same side as is input "side")
    # increase by to_be_minted (opposite side as is input "side")
    # The reason behind different different sides is following (example)
    # user goes long, so we want to resell long position to the user (to_be_traded)
    #   -> decrease the "side" pool_option_balance
    #      to level of available_option_balance - to_be_traded
    # if we have to mint new options, we mint long and short, user gets long, pool
    # keeps short and puts it into the pool
    #   -> increase the "opposite_sied" of pool_option_balance

    let (new_pool_option_balance) = Math64x61_sub(available_option_balance, to_be_traded)
    set_pool_option_balance(option_type, strike_price, maturity, side, new_pool_option_balance)
    let (new_opposite_pool_option_balance) = Math64x61_add(
        available_opposite_option_balance, to_be_minted
    )
    set_pool_option_balance(
        option_type, strike_price, maturity, opposite_side, new_opposite_pool_option_balance
    )

    # 4) Update the pool_balance
    # if side==TRADE_SIDE_SHORT increase pool_balance by
    # if option_type==OPTION_CALL increase (call pool) it by to_be_traded
    # if option_type==OPTION_PUT increase (put pool) it by to_be_traded*underlying_price
    # if side==TRADE_SIDE_LONG decrease pool_balance by
    # if option_type==OPTION_CALL decrease it by to_be_minted
    # if option_type==OPTION_PUT decrease it by to_be_minted*underlying_price

    # new_pool_balance is current state of the pool (from above) in terms of the pool's token
    let (new_pool_balance_after_locking_capital) = _calc_new_pool_balance_with_locked_capital(
        side, option_type, new_pool_balance, underlying_price, to_be_traded, to_be_minted
    )
    set_pool_balance(option_type, new_pool_balance_after_locking_capital)

    return (premia=premia)
end

@external
func trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt,
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    option_size : felt,
) -> (premia : felt):
    # FIXME: with get_available_options check that option is available

    # option_type is from {OPTION_CALL, OPTION_PUT}
    # option_size is denominated in TOKEN_A (ETH)
    # side is from {TRADE_SIDE_LONG, TRADE_SIDE_SHORT}, where both are from user perspective,
    # ie "TRADE_SIDE_LONG" means that the pool is underwriting option and the "TRADE_SIDE_SHORT"
    # means that user is underwriting the option.

    # 1) Check that account_id has enough amount of given token to
    # - to pay the fee
    # - to pay the premia in case of size==TRADE_SIDE_LONG
    # - to lock in capital in case of size==TRADE_SIDE_SHORT
    # FIXME: do this once test or actual capital is used

    # 2) Check that there is enough available capital in the given pool_balance
    # - to pay the premia in case of size==TRADE_SIDE_LONG
    # - to lock in capital in case of size==TRADE_SIDE_SHORT

    # 3) Check that the strike_price > 0, check that the maturity haven't passed yet

    # 4) Check that the strike_price x maturity option is at all available

    # 5) Check that option_size>0

    let (premia) = do_trade(account_id, option_type, strike_price, maturity, side, option_size)
    return (premia=premia)
end
