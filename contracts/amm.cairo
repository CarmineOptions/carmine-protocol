// Internals of the AMM

%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn_le, assert_nn
from starkware.starknet.common.syscalls import get_block_timestamp
from math64x61 import Math64x61

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
    RISK_FREE_RATE,
)
from contracts.fees import get_fees
from contracts.option_pricing import black_scholes
from contracts.oracles import empiric_median_price
from contracts._cfg import EMPIRIC_ETH_USD_KEY
from contracts.interface_liquidity_pool import ILiquidityPool


// FIXME: look into how the token sizes are dealt with across different protocols
// A map from account and token type to the corresponding balance of that account in given pool.
// Ie this describes how much of the given pool the given account owns.
@storage_var
func account_balance(account_id: felt, token_type: felt) -> (balance: felt) {
}

// A map from option type to the corresponding balance of the pool.
@storage_var
func pool_balance(option_type: felt) -> (balance: felt) {
}

// Stores information about underwritten or bought options that the AMM could
// use instead of minting a new option. If balance > 0 -> pool does not have to
// mint new options if user wants to buy, balance < 0 means the same when
// user wants to sell.
@storage_var
func pool_option_balance(option_type: felt, strike_price: felt, maturity: felt, side: felt) -> (
    balance: felt
) {
}

// Stores current value of volatility for given pool (option type) and maturity.
@storage_var
func pool_volatility(option_type: felt, maturity: felt) -> (volatility: felt) {
}

// Determines whether an option is allowed or not. If 1 is returned, option is allowed.
// FIXME: is this a good design?
@storage_var
func available_options(option_type: felt, strike_price: felt, maturity: felt) -> (
    availability: felt
) {
}

@storage_var
func pool_address_for_given_asset_and_option_type(asset: felt, option_type: felt) -> (
    address: felt
):
end


# ---------------storage_var handlers------------------

func set_pool_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt, balance: felt
) {
    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;
    assert_nn_le(balance, POOL_BALANCE_UPPER_BOUND - 1);
    pool_balance.write(option_type, balance);
    return ();
}

func set_account_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account_id: felt, token_type: felt, balance: felt
) {
    assert (token_type - TOKEN_A) * (token_type - TOKEN_B) = 0;
    assert_nn_le(balance, POOL_BALANCE_UPPER_BOUND - 1);
    account_balance.write(account_id, token_type, balance);
    return ();
}

func set_pool_option_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt, strike_price: felt, maturity: felt, side: felt, balance: felt
) {
    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;
    assert (side - TRADE_SIDE_LONG) * (side - TRADE_SIDE_SHORT) = 0;
    assert_nn_le(balance, POOL_BALANCE_UPPER_BOUND - 1);
    // FIXME: assert maturity
    // FIXME: assert side

    pool_option_balance.write(option_type, strike_price, maturity, side, balance);
    return ();
}

func set_pool_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt, maturity: felt, volatility: felt
) {
    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;
    assert_nn_le(volatility, VOLATILITY_UPPER_BOUND - 1);
    assert_nn_le(VOLATILITY_LOWER_BOUND, volatility);  // TODO why? vol - 1
    pool_volatility.write(option_type, maturity, volatility);
    return ();
}

func set_available_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt, strike_price: felt, maturity: felt
) {
    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;
    // FIXME: assert that maturity > current time
    assert_nn_le(strike_price, STRIKE_PRICE_UPPER_BOUND - 1);

    // Sets the availability of option to 1 (True)
    available_options.write(option_type, strike_price, maturity, 1);
    return ();
}

@view
func get_pool_available_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt
) -> (pool_balance : felt):
    let (pool_balance_) = pool_balance.read(option_type)
    return (pool_balance_)
end

@view
func get_account_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account_id: felt, token_type: felt
) -> (account_balance: felt) {
    let (account_balance_) = account_balance.read(account_id, token_type);
    return (account_balance_,);
}

@view
func get_pool_option_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt, strike_price: felt, maturity: felt, side: felt
) -> (pool_option_balance: felt) {
    let (pool_option_balance_) = pool_option_balance.read(
        option_type, strike_price, maturity, side
    );
    return (pool_option_balance_,);
}

@view
func get_pool_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt, maturity: felt
) -> (pool_volatility: felt) {
    let (pool_volatility_) = pool_volatility.read(option_type, maturity);
    return (pool_volatility_,);
}

@view
func get_available_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt, strike_price: felt, maturity: felt
) -> (option_availability: felt) {
    let (option_availability_) = available_options.read(option_type, strike_price, maturity);
    return (option_availability_,);
}

// ---------------AMM logic------------------

func _select_and_adjust_premia{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    call_premia: felt, put_premia: felt, option_type: felt, underlying_price: felt
) -> (premia: felt) {
    // Call and put premia are in quote tokens (in USDC in case of ETH/USDC)

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    if (option_type == OPTION_CALL) {
        let (adjusted_call_premia) = Math64x61.div(call_premia, underlying_price);
        return (premia=adjusted_call_premia);
    }
    return (premia=put_premia);
}

func _calc_new_pool_balance_with_premia{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(side: felt, current_pool_balance: felt, total_premia: felt) -> (pool_balance: felt) {
    if (side == TRADE_SIDE_LONG) {
        // User goes long and pays premia to the pool_balance
        let (long_pool_balance) = Math64x61.add(current_pool_balance, total_premia);
        return (long_pool_balance,);
    }
    // User goes short and pool pays premia to the user
    let (short_pool_balance) = Math64x61.sub(current_pool_balance, total_premia);
    return (short_pool_balance,);
}

func _time_till_maturity{syscall_ptr: felt*, range_check_ptr}(maturity: felt) -> (
    time_till_maturity: felt
) {
    alloc_locals;
    local syscall_ptr: felt* = syscall_ptr;  // Reference revoked fix

    let (currtime) = get_block_timestamp();  // is number of seconds... unix timestamp
    let (currtime_math) = Math64x61.fromFelt(currtime);
    let (maturity_math) = Math64x61.fromFelt(maturity);
    let (secs_in_year) = Math64x61.fromFelt(60 * 60 * 24 * 365);

    let (secs_left) = Math64x61.sub(maturity_math, currtime_math);
    assert_nn(secs_left);

    let (time_till_maturity) = Math64x61.div(secs_left, secs_in_year);
    return (time_till_maturity,);
}

func _calc_new_pool_balance_with_locked_capital{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    side: felt,
    option_type: felt,
    current_pool_balance: felt,
    strike_price: felt,
    to_be_traded: felt,
    to_be_minted: felt,
) -> (pool_balance: felt) {
    // if side==TRADE_SIDE_SHORT increase pool_balance by
    // if option_type==OPTION_CALL increase (call pool) it by to_be_traded
    // if option_type==OPTION_PUT increase (put pool) it by to_be_traded*underlying_price
    // if side==TRADE_SIDE_LONG decrease pool_balance by
    // if option_type==OPTION_CALL decrease it by to_be_minted
    // if option_type==OPTION_PUT decrease it by to_be_minted*underlying_price

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;
    assert (side - TRADE_SIDE_SHORT) * (side - TRADE_SIDE_LONG) = 0;

    if (side == TRADE_SIDE_SHORT) {
        // pool unlocks locked capital in size of to_be_traded
        if (option_type == OPTION_CALL) {
            let (to_be_traded_call_short) = Math64x61.add(current_pool_balance, to_be_traded);
            return (to_be_traded_call_short,);
        }
        let (to_be_traded_put) = Math64x61.mul(to_be_traded, strike_price);
        let (to_be_traded_put_short) = Math64x61.add(current_pool_balance, to_be_traded_put);
        return (to_be_traded_put_short,);
    }
    // here the side = TRADE_SIDE_LONG
    if (option_type == OPTION_CALL) {
        assert_nn_le(to_be_minted, current_pool_balance - 1);
        let (to_be_minted_call_long) = Math64x61.sub(current_pool_balance, to_be_minted);
        return (to_be_minted_call_long,);
    }
    let (to_be_minted_put) = Math64x61.mul(to_be_minted, strike_price);
    assert_nn_le(to_be_minted_put, current_pool_balance - 1);
    let (to_be_minted_put_long) = Math64x61.sub(current_pool_balance, to_be_minted_put);
    return (to_be_minted_put_long,);
}

func _add_premia_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    side: felt, total_premia_before_fees: felt, total_fees: felt
) -> (total_premia: felt) {
    assert (side - TRADE_SIDE_SHORT) * (side - TRADE_SIDE_LONG) = 0;

    // if side == TRADE_SIDE_LONG (user pays premia) the fees are added on top of premia
    // if side == TRADE_SIDE_SHORT (user receives premia) the fees are subtracted from the premia
    if (side == TRADE_SIDE_LONG) {
        let (premia_fees_add) = Math64x61.add(total_premia_before_fees, total_fees);
        return (premia_fees_add,);
    }
    let (premia_fees_sub) = Math64x61.sub(total_premia_before_fees, total_fees);
    return (premia_fees_sub,);
}

func _get_vol_update_denominator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    relative_option_size: felt, side: felt
) -> (relative_option_size: felt) {
    if (side == TRADE_SIDE_LONG) {
        let (long_denominator) = Math64x61.sub(Math64x61.ONE, relative_option_size);
        return (long_denominator,);
    }
    let (short_denominator) = Math64x61.add(Math64x61.ONE, relative_option_size);
    return (short_denominator,);
}

func _get_new_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    current_volatility: felt, option_size: felt, option_type: felt, side: felt
) -> (new_volatility: felt, trade_volatility: felt) {
    alloc_locals;

    let (current_pool_balance) = get_pool_balance(option_type);
    assert_nn_le(Math64x61.ONE, current_pool_balance);
    assert_nn_le(option_size, current_pool_balance);
    let (relative_option_size) = Math64x61.div(option_size, current_pool_balance);

    // alpha – rate of change assumed to be 1
    let (denominator) = _get_vol_update_denominator(relative_option_size, side);
    let (volatility_scale) = Math64x61.div(Math64x61.ONE, denominator);
    let (new_volatility) = Math64x61.mul(current_volatility, volatility_scale);

    let (volsum) = Math64x61.add(current_volatility, new_volatility);
    let (two) = Math64x61.fromFelt(2);
    let (trade_volatility) = Math64x61.div(volsum, two);

    return (new_volatility=new_volatility, trade_volatility=trade_volatility);
}

func do_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt,
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    option_size : felt,
    underlying_asset: felt,
) -> (premia : felt):
    # options_size is always denominated in base tokens (ETH in case of ETH/USDC)

func do_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account_id: felt,
    option_type: felt,
    strike_price: felt,
    maturity: felt,
    side: felt,
    option_size: felt,
) -> (premia: felt) {
    // options_size is always denominated in base tokens (ETH in case of ETH/USDC)

    alloc_locals;

    // 0) Get current volatility
    let (current_volatility) = get_pool_volatility(option_type, maturity);

    // 1) Get price of underlying asset
    let (underlying_price) = empiric_median_price(EMPIRIC_ETH_USD_KEY);

    // 2) Calculate new volatility, calculate trade volatilit
    let (option_size_in_pool_currency) = _get_option_size_in_pool_currency(
        option_size, option_type, underlying_price
    );
    let (new_volatility, trade_volatility) = _get_new_volatility(
        current_volatility, option_size_in_pool_currency, option_type, side
    );

    // 3) Update volatility
    set_pool_volatility(option_type, maturity, new_volatility);

    // 4) Get time till maturity
    let (time_till_maturity) = _time_till_maturity(maturity);

    // 5) risk free rate
    let (risk_free_rate_annualized) = RISK_FREE_RATE;

    // 6) Get premia
    let (call_premia, put_premia) = black_scholes(
        sigma=trade_volatility,
        time_till_maturity_annualized=time_till_maturity,
        strike_price=strike_price,
        underlying_price=underlying_price,
        risk_free_rate_annualized=risk_free_rate_annualized,
    );

    // 7) Make the trade
    // pool address and option token address
    let (pool_address) = pool_address_for_given_asset_and_option_type.read(underlying_asset, option_type)

    # FIXME: consider dropping the option_token_address and finding it inside of the liquidity_pool.mint_option_token
    let (option_token_address) = ILiquidityPool.get_option_token_address(
        contract_address=pool_address,
        option_side=side,
        option_type=option_type,
        maturity=maturity,
        strike_price=strike_price
    )
    # 1.1) mint_option_token
    # FIXME: do we want to have here the premia and fees separately or combined???
    ILiquidityPool.mint_option_token(
        contract_address=pool_address,
        option_token_address=option_token_address,
        amount=option_size,
        option_side=side,
        option_type=option_type,
        maturity=maturity,
        strike=strike_price,
        premia=total_premia_before_fees,
        fees=total_fees,
        underlying_price=underlying_price,
    )
    # 1.2) burn_option_token
        # !!! implemented in close_position function

    return (premia=premia);
}

@external
func trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt,
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    option_size : felt,
    underlying_asset: felt,
    open_position: felt, # True or False
) -> (premia : felt):
    if open_position == TRUE:
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

        let (premia) = do_trade(account_id, option_type, strike_price, maturity, side, option_size, underlying_asset)
        return (premia=premia)
    else:
        # FIXME: needs verification as above
        let (premia) = close_position(
            account_id,
            option_type,
            strike_price,
            maturity,
            side,
            option_size,
            underlying_asset
        )
        return (premia=premia)
    end
end

func close_position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt,
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    option_size : felt,
    underlying_asset: felt,
    open_position: felt,
) -> (premia : felt):
    # FIXME: close position has to be implemented to return locked capital to the user
    # (or not to lock additional capital in case of closing long)
    return ()
end
