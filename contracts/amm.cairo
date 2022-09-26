// Internals of the AMM

%lang starknet

from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn_le, assert_nn, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.starknet.common.syscalls import get_block_timestamp
from math64x61 import Math64x61

from contracts.constants import (
    VOLATILITY_LOWER_BOUND,
    VOLATILITY_UPPER_BOUND,
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    TRADE_SIDE_SHORT,
    RISK_FREE_RATE,
    STOP_TRADING_BEFORE_MATURITY_SECONDS,
    EMPIRIC_ETH_USD_KEY,
    get_empiric_key,
)
from contracts.fees import get_fees
from contracts.interface_liquidity_pool import ILiquidityPool
from contracts.option_pricing import black_scholes
from contracts.oracles import empiric_median_price
from contracts.types import (Bool, Wad, Math64x61_, OptionType, OptionSide, Int, Address)
from contracts.option_pricing_helpers import (
    select_and_adjust_premia,
    get_time_till_maturity,
    add_premia_fees,
    get_new_volatility,
    convert_amount_to_option_currency_from_base
)


@storage_var
func pool_address_for_given_asset_and_option_type(asset: felt, option_type: OptionType) -> (
    address: Address
) {
}


// ############################
// Pool information handlers
// ############################


@view
func get_pool_available_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type: OptionType
) -> (pool_balance: felt) {
    // Returns total capital in the pool minus the locked capital
    // (ie capital available to locking).
    // FIXME: Implement ILiqPool.get_unlocked_capital
    let (pool_balance_) = ILiquidityPool.get_unlocked_capital(
        contract_address=pool_address
    );
    return (pool_balance_,);
}


@view
func is_option_available{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pool_address: Address, option_side: OptionSide, strike_price: Math64x61_, maturity: Int
) -> (option_availability: felt) {
    let (option_address) = ILiquidityPool.get_option_token_address(
        contract_address=pool_address,
        option_side=option_side,
        maturity=maturity,
        strike_price=strike_price
    );
    // FIXME: create unit test for this
    if (option_address == 0) {
        return (FALSE,);
    }

    return (TRUE,);
}


// ############################
// AMM Trade, Close and Expire
// ############################


func do_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: OptionType,
    strike_price: Math64x61_,
    maturity: Int,
    side: OptionSide,
    option_size: Math64x61_,
    underlying_asset: felt
) -> (premia: Math64x61_) {
    // options_size is always denominated in base tokens (ETH in case of ETH/USDC)

    alloc_locals;

    // 0) Get pool address
    let (pool_address) = pool_address_for_given_asset_and_option_type.read(
        underlying_asset,
        option_type
    );

    // 1) Get current volatility
    let (current_volatility) = ILiquidityPool.get_pool_volatility(
        contract_address=pool_address,
        maturity=maturity
    );

    // 2) Get price of underlying asset
    let (empiric_key) = get_empiric_key(underlying_asset);
    let (underlying_price) = empiric_median_price(empiric_key);

    // 3) Calculate new volatility, calculate trade volatilit
    let (current_pool_balance) = get_pool_available_balance(pool_address);
    assert_nn_le(Math64x61.ONE, current_pool_balance);
    assert_nn_le(option_size_in_pool_currency, current_pool_balance);

    let (new_volatility, trade_volatility) = get_new_volatility(
        current_volatility, option_size, option_type, side, underlying_price, current_pool_balance
    );

    // 4) Update volatility
    let (current_volatility) = ILiquidityPool.set_pool_volatility(
        contract_address=pool_address,
        maturity=maturity,
        volatility=new_volatility
    );

    // 5) Get time till maturity
    let (time_till_maturity) = get_time_till_maturity(maturity);

    // 6) risk free rate
    let (risk_free_rate_annualized) = RISK_FREE_RATE;

    // 7) Get premia
    // call_premia, put_premia in quote tokens (USDC in case of ETH/USDC)
    let (call_premia, put_premia) = black_scholes(
        sigma=trade_volatility,
        time_till_maturity_annualized=time_till_maturity,
        strike_price=strike_price,
        underlying_price=underlying_price,
        risk_free_rate_annualized=risk_free_rate_annualized,
    );
    // AFTER THE LINE BELOW, THE PREMIA IS IN TERMS OF CORRESPONDING POOL
    // Ie in case of call option, the premia is in base (ETH in case ETH/USDC)
    // and in quote tokens (USDC in case of ETH/USDC) for put option.
    let (premia) = select_and_adjust_premia(
        call_premia, put_premia, option_type, underlying_price
    );
    // premia adjusted by size (multiplied by size)
    let total_premia_before_fees = Math64x61.mul(premia, option_size);

    // 8) Get fees
    // fees are already in the currency same as premia
    // if side == TRADE_SIDE_LONG (user pays premia) the fees are added on top of premia
    // if side == TRADE_SIDE_SHORT (user receives premia) the fees are substracted from the premia
    let (total_fees) = get_fees(total_premia_before_fees);
    let (total_premia) = add_premia_fees(side, total_premia_before_fees, total_fees);

    // 9) Make the trade
    let (option_size_in_pool_currency) = convert_amount_to_option_currency_from_base(
        option_size,
        option_type,
        strike_price
    );

    ILiquidityPool.mint_option_token(
        contract_address=pool_address,
        option_size=option_size,
        option_size_in_pool_currency=option_size_in_pool_currency,
        option_side=side,
        option_type=option_type,
        maturity=maturity,
        strike=strike_price,
        premia_including_fees=total_premia,
        underlying_price=underlying_price,
    );

    return (premia=premia);
}

func close_position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : OptionType,
    strike_price : Math64x61_,
    maturity : felt,
    side : felt,
    option_size : felt,
    underlying_asset: felt,
    open_position: felt,
) -> (premia : felt) {
    // All of the unlocking of capital happens inside of the burn function below.
    // Volatility is not updated since closing position is considered as
    // "user does not have opinion on the market state" - this may change down the line

    // When the user is closing, side is the side of the token being closed... for calculations
    // we need opposite side, since the user is doing "opposite" action
    // to acquiring the option token.

    alloc_locals;

    let (opposite_side) = get_opposite_side(side);

    // 0) Get pool address
    let (pool_address) = pool_address_for_given_asset_and_option_type.read(
        underlying_asset,
        option_type
    );

    // 1) Get current volatility
    let (current_volatility) = ILiquidityPool.get_pool_volatility(
        contract_address=pool_address,
        maturity=maturity
    );

    // 2) Get price of underlying asset
    let (empiric_key) = get_empiric_key(underlying_asset);
    let (underlying_price) = empiric_median_price(empiric_key);

    // 3) Calculate new volatility, calculate trade volatilit
    let (new_volatility, trade_volatility) = get_new_volatility(
        current_volatility, option_size, option_type, opposite_side, underlying_price, pool_address
    );

    // 4) Update volatility
    // Update volatility does not happen in this function - look at docstring

    // 5) Get time till maturity
    let (time_till_maturity) = get_time_till_maturity(maturity);

    // 6) risk free rate
    let (risk_free_rate_annualized) = RISK_FREE_RATE;

    // 7) Get premia
    // call_premia, put_premia in quote tokens (USDC in case of ETH/USDC)
    let (call_premia, put_premia) = black_scholes(
        sigma=trade_volatility,
        time_till_maturity_annualized=time_till_maturity,
        strike_price=strike_price,
        underlying_price=underlying_price,
        risk_free_rate_annualized=risk_free_rate_annualized,
    );
    // AFTER THE LINE BELOW, THE PREMIA IS IN TERMS OF CORRESPONDING POOL
    // Ie in case of call option, the premia is in base (ETH in case ETH/USDC)
    // and in quote tokens (USDC in case of ETH/USDC) for put option.
    let (premia) = select_and_adjust_premia(
        call_premia, put_premia, option_type, underlying_price
    );
    // premia adjusted by size (multiplied by size)
    let (total_premia_before_fees) = Math64x61.mul(premia, option_size);

    // 8) Get fees
    // fees are already in the currency same as premia
    // if opposite_side == TRADE_SIDE_LONG (user pays premia) the fees are added on top of premia
    // if opposite_side == TRADE_SIDE_SHORT (user receives premia) the fees are substracted from the premia
    let (total_fees) = get_fees(total_premia_before_fees);
    let (total_premia) = add_premia_fees(opposite_side, total_premia_before_fees, total_fees);

    // 9) Make the trade
    let (option_size_in_pool_currency) = convert_amount_to_option_currency_from_base(
        option_size,
        option_type,
        strike_price
    );
    
    ILiquidityPool.burn_option_token(
        contract_address=pool_address,
        option_size=option_size,
        option_size_in_pool_currency=option_size_in_pool_currency,
        option_side=opposite_side,
        option_type=option_type,
        maturity=maturity,
        strike=strike_price,
        premia_including_fees=total_premia,
        underlying_price=underlying_price,
    );

    return (premia=premia);
}

func settle_option_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : OptionType,
    strike_price : Math64x61_,
    maturity : Int,
    side : OptionSide,
    option_size : Math64x61_,
    underlying_asset: felt,
    open_position: Bool, // True or False... determines if the user wants to open or close the position
) -> () {
    let (terminal_price) = FIXME;

    let (pool_address) = pool_address_for_given_asset_and_option_type.read(
        underlying_asset,
        option_type
    );

    ILiquidityPool.expire_option_token(
        contract_address=pool_address,
        option_type=option_type,
        option_side=side,
        strike_price=strike_price,
        terminal_price=terminal_price,
        option_size=option_size,
        maturity=maturity,
    );
    return ();
}


@external
func trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : OptionType,
    strike_price : Math64x61_,
    maturity : Int,
    side : OptionSide,
    option_size : Math64x61_,
    underlying_asset: felt,
    open_position: Bool, // True or False... determines if the user wants to open or close the position
) -> (premia : Math64x61_) {
    // side is dependent on open_position...
    //  if open_position=TRUE -> side is what the user want's to do as action
    //  if open_position=False -> side is what the user want's to close
    //      (side of the token that user holds)
    //      This is very important is in close_position an opposite side is used

    let (pool_address) = pool_address_for_given_asset_and_option_type.read(
        underlying_asset,
        option_type
    );
    let (option_is_available) = is_option_available(
        pool_address,
        side,
        strike_price,
        maturity
    );
    with_attr error_message("Option is not available") {
        assert option_is_available = TRUE;
    }

    with_attr error_message("Given option_type is not available") {
        assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;
    }

    with_attr error_message("Given option_side is not available") {
        assert (option_side - TRADE_SIDE_LONG) * (option_side - TRADE_SIDE_SHORT) = 0;
    }

    with_attr error_message("open_position is not bool") {
        assert (open_position - TRUE) * (open_position - fALSE) = 0;
    }

    // Check that option_size>0 (same as size>=1... because 1 is a smallest unit)
    with_attr error_message("Option size is not positive") {
        assert_le(1, option_size);
    }

    // Check that maturity hasn't matured in case of open_position=TRUE
    // If open_position=FALSE it means the user wants to close or settle the option
    let (current_block_time) = get_block_timestamp();
    if (open_position == TRUE) {
        with_attr error_message("Given maturity has already expired") {
            assert_le(current_block_time, maturity);
        }
        with_attr error_message("Trading of given maturity has been stopped before expiration") {
            assert_le(current_block_time, maturity - STOP_TRADING_BEFORE_MATURITY_SECONDS);
        }
    } else {
        let (is_not_ripe) = is_le(current_block_time, maturity);
        let (cannot_be_closed) = is_le(maturity - STOP_TRADING_BEFORE_MATURITY_SECONDS, current_block_time);
        let (cannot_be_closed_or_settled) = is_not_ripe * cannot_be_closed;
        with_attr error_message(
            "Closing positions or settling option of given maturity is not possible just before expiration"
        ) {
            assert cannot_be_closed_or_settled = 0;
        }
    }

    // Check that account has enough amount of given token to pay for premia and/or locked capital.
    // If this is not the case, the transaction fails, because the tokens can't be transfered.

    // Check that there is enough available capital in the given pool.
    // If this is not the case, the transaction fails, because the tokens can't be transfered.

    if (open_position == TRUE) {
        let (premia) = do_trade(
            option_type,
            strike_price,
            maturity,
            side,
            option_size,
            underlying_asset
        );
        return (premia=premia);
    } else {
        let (can_be_closed) = is_le(current_block_time, maturity - STOP_TRADING_BEFORE_MATURITY_SECONDS);
        if (can_be_closed == TRUE) {
            let (premia) = close_position(
                option_type,
                strike_price,
                maturity,
                side,
                option_size,
                underlying_asset
            );
            return (premia=premia);
        } else {
            settle_option_token(
                option_type=option_type,
                strike_price=strike_price,
                maturity=maturity,
                side=side,
                option_size=option_size,
                underlying_asset=underlying_asset,
                open_position=open_position
            );
            return (premia=0);
        }
    }
}
