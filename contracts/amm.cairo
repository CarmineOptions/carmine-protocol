# Internals of the AMM

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
# from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_nn_le
# from starkware.cairo.common.math import assert_le, unsigned_div_rem
# from starkware.starknet.common.syscalls import storage_read, storage_write
from contracts.Math64x61 import (
    Math64x61_fromFelt,
    Math64x61_mul,
    Math64x61_div,
    Math64x61_add,
    Math64x61_sub
)


from contracts.constants import (POOL_BALANCE_UPPER_BOUND, ACCOUNT_BALANCE_UPPER_BOUND, 
    VOLATILITY_LOWER_BOUND, VOLATILITY_UPPER_BOUND, TOKEN_A, TOKEN_B, OPTION_CALL, OPTION_PUT,
    TRADE_SIDE_LONG, TRADE_SIDE_SHORT, STRIKE_PRICE_UPPER_BOUND)
from contracts.option_pricing import black_scholes


# FIXME: look into how the token sizes are dealt with across different protocols
# A map from account and token type to the corresponding balance of that account in given pool.
# FIXME: This is at the moment not used.
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
func pool_option_balance(
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt
) -> (
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
func available_options(
    option_type : felt,
    strike_price : felt,
    maturity : felt
) -> (
    availability : felt
):
end


#---------------storage_var handlers------------------

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
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    balance : felt
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
    assert_nn_le(VOLATILITY_LOWER_BOUND, volatility - 1)
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
) -> (
    pool_balance: felt
):
    let (pool_balance_) = pool_balance.read(option_type)
    return (pool_balance_)
end

@view
func get_account_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt, token_type : felt
) -> (
    account_balance: felt
):
    let (account_balance_) = account_balance.read(account_id, token_type)
    return (account_balance_)
end

@view
func get_pool_option_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt
) -> (
    pool_option_balance: felt
):
    let (pool_option_balance_) = pool_option_balance.read(option_type, strike_price, maturity, side)
    return (pool_option_balance_)
end

@view
func get_pool_volatility{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt, maturity : felt
) -> (
    pool_volatility: felt
):
    let (pool_volatility_) = pool_volatility.read(option_type, maturity)
    return (pool_volatility_)
end

@view
func get_available_options{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt, strike_price : felt, maturity : felt
) -> (
    option_availability: felt
):
    let (option_availability_) = available_options.read(option_type, strike_price, maturity)
    return (option_availability_)
end



#---------------AMM logic------------------

func _select_and_adjust_premia{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    call_premia : felt,
    put_premia : felt,
    option_type : felt,
    underlying_price : felt,
) -> (premia: felt):

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0

    if option_type == OPTION_CALL:
        let (adjusted_call_premia) = Math64x61_div(call_premia, underlying_price)
        return (premia=adjusted_call_premia)
    end
    return (premia=put_premia)
end

func _calc_new_pool_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    side : felt,
    current_pool_balance : felt,
    total_premia : felt
) -> (pool_balance : felt):
    if side == TRADE_SIDE_LONG:
        # User goes long and pays premia to the pool_balance
        let (long_pool_balance) = Math64x61_add(current_pool_balance, total_premia)
        return (long_pool_balance)
    end
    # User goes short and pool pays premia to the user
    let (short_pool_balance) = Math64x61_sub(current_pool_balance, total_premia)
    return (short_pool_balance)
end

func do_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt,
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    option_size : felt,
) -> (premia: felt):
    # options_size is always denominated in base tokens (ETH in case of ETH/USDC)

    alloc_locals

    # 0) Get current volatility
    let (volatility) = Math64x61_fromFelt(1)
    # 1) Calculate new volatility, calculate trade volatility

    # 2) Update volatility

    # 3) Get price of underlying asset
    let (underlying_price) = Math64x61_fromFelt(1000)

    # 4) Get time till maturity
    let (one) = Math64x61_fromFelt(1)
    let (ten) = Math64x61_fromFelt(10)
    let (time_till_maturity) = Math64x61_div(one, ten) # 0.1 year

    # 5) risk free rate
    let (three) = Math64x61_fromFelt(3)
    let (hundred) = Math64x61_fromFelt(100)
    # let (risk_free_rate_annualized) = Math64x61_div(three, hundred)
    let (risk_free_rate_annualized) = Math64x61_fromFelt(0)

    # 6) Get premia
    let (call_premia, put_premia) = black_scholes(
        sigma=volatility,
        time_till_maturity_annualized=time_till_maturity,
        strike_price=strike_price,
        underlying_price=underlying_price,
        risk_free_rate_annualized=risk_free_rate_annualized
    )
    # AFTER THE LINE BELOW, THE PREMIA IS IN TERMS OF CORRESPONDING POOL
    # Ie in case of call option, the premia is in base (ETH in case ETH/USDC)
    # and in quote tokens (USDC in case of ETH/USDC) for put option.
    let (premia) = _select_and_adjust_premia(call_premia, put_premia, option_type, underlying_price)
    # premia adjusted by size (multiplied by size)
    let (total_premia) = Math64x61_mul(premia, option_size)

    # 7) Get fees
    # FIXME: add fees to premia, the fees are not added at the moment (add/sub depending on side)


    # 1) Update the pool_balance
        # increase by the amount of fees (in corresponding TOKEN)
        # if side==TRADE_SIDE_LONG increase pool_balance by premia (in corresponding TOKEN)
        # if side==TRADE_SIDE_SHORT decrease pool_balance by premia (in corresponding TOKEN)
    let (current_pool_balance) = get_pool_balance(option_type)

    let (new_pool_balance) = _calc_new_pool_balance(side, current_pool_balance, total_premia)
    set_pool_balance(option_type, new_pool_balance)


    # 2) get size of options that could be "traded" and not "minted" from pool_option_balance
    # if there are available ones, trade them, if not mint new ones
    # (could be partially traded and partially minted).
    #...... let (available_option_balance) =

    # available_option_balance is always >= 0
    #...... let (to_be_traded) = min(available_option_balance, option_size)
    #...... let (to_be_minted) = option_size - to_be_traded

    # 3) Update the pool_option_balance
        # decrease by to_be_traded
        # increase by to_be_minted
        # NOTE: the decrease and increase are of different storage var
            # (same option, but one storage var is for long, the other for short)

    # 4) Update the pool_balance
        # if side==TRADE_SIDE_SHORT increase pool_balance by
            # if option_type==OPTION_CALL increase (call pool) it by to_be_traded
            # if option_type==OPTION_PUT increase (put pool) it by to_be_traded*underlying_price
        # if side==TRADE_SIDE_LONG decrease pool_balance by
            # if option_type==OPTION_CALL decrease it by to_be_minted
            # if option_type==OPTION_PUT decrease it by to_be_minted*underlying_price


    return (premia=premia)
    # return (premia=call_premia)
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
