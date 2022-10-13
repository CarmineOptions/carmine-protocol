// Helper functions

%lang starknet

from contracts.constants import (
    OPTION_CALL,
    TRADE_SIDE_LONG,
    RISK_FREE_RATE,
    get_empiric_key,
    get_opposite_side
)
from contracts.fees import get_fees
from contracts.option_pricing import black_scholes
from contracts.oracles import empiric_median_price
from contracts.option_pricing_helpers import (
    select_and_adjust_premia,
    get_time_till_maturity,
    add_premia_fees,
    get_new_volatility
)
from contracts.types import Option

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from math64x61 import Math64x61

func max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value_a: felt, value_b: felt
) -> (max_value: felt) {
    let a_smaller_b = is_le(value_a, value_b);

    if (a_smaller_b == TRUE) {
        return (value_b,);
    }
    return (value_a,);
}

func min{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value_a: felt, value_b: felt
) -> (max_value: felt) {
    let a_smaller_b = is_le(value_a, value_b);

    if (a_smaller_b == TRUE) {
        return (value_a,);
    }
    return (value_b,);
}


func _get_value_of_position{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option: Option,
    position_size: felt,
    option_type: felt,
    current_volatility: felt,
    current_pool_balance: felt
) -> (position_value: felt){
    // Gets value of position ADJUSTED for fees!!!

    alloc_locals;

    let side = option.option_side;
    let maturity = option.maturity;
    let strike_price = option.strike_price;
    let quote_token_address = option.quote_token_address;
    let base_token_address = option.base_token_address;

    let option_size = position_size;

    // 1) Get price of underlying asset
    with_attr error_message("helpers._get_value_of_position getting undrelying price FAILED"){
        let (empiric_key) = get_empiric_key(quote_token_address, base_token_address);
        let (underlying_price) = empiric_median_price(empiric_key);
    }

    // 2) Calculate new volatility, calculate trade volatility
    with_attr error_message("helpers._get_value_of_position getting volatility FAILED"){
        let (_, trade_volatility) = get_new_volatility(
            current_volatility, option_size, option_type, side, underlying_price, current_pool_balance
        );
    }

    // 3) Get time till maturity
    with_attr error_message("helpers._get_value_of_position getting time_till_maturity FAILED"){
        let (time_till_maturity) = get_time_till_maturity(maturity);
    }

    // 4) risk free rate
    let risk_free_rate_annualized = RISK_FREE_RATE;

    // 5) Get premia
    with_attr error_message("helpers._get_value_of_position getting premia FAILED"){
        // call_premia, put_premia in quote tokens (USDC in case of ETH/USDC)
        let (call_premia, put_premia) = black_scholes(
            sigma=trade_volatility,
            time_till_maturity_annualized=time_till_maturity,
            strike_price=strike_price,
            underlying_price=underlying_price,
            risk_free_rate_annualized=risk_free_rate_annualized,
        );
    }

    with_attr error_message("helpers._get_value_of_position adjusting premia FAILED"){
        // AFTER THE LINE BELOW, THE PREMIA IS IN TERMS OF CORRESPONDING POOL
        // Ie in case of call option, the premia is in base (ETH in case ETH/USDC)
        // and in quote tokens (USDC in case of ETH/USDC) for put option.
        let (premia) = select_and_adjust_premia(
            call_premia, put_premia, option_type, underlying_price
        );
        // premia adjusted by size (multiplied by size)
        let total_premia_before_fees = Math64x61.mul(premia, option_size);
    }

    // 6) Get fees and total premia
    with_attr error_message("helpers._get_value_of_position getting fees FAILED"){
        // fees are already in the currency same as premia
        // Value of position is calculated as "how much remaining value would holder get if liquidated"
        // For long the holder's position is valued as "premia - fees", this is similar to closing
        //      the given position.
        // For short the holder's position is valued as "locked capital - premia - fees" since it would
        //      be the remaining capital if closed position
        let (total_fees) = get_fees(total_premia_before_fees);
        let (opposite_side) = get_opposite_side(side);
        let (premia_with_fees) = add_premia_fees(opposite_side, total_premia_before_fees, total_fees);
        if (side == TRADE_SIDE_LONG) {
            return (position_value=premia_with_fees);
        }
    }

    if (option_type == OPTION_CALL) {
        let locked_capital = option_size;
        let locked_and_premia_with_fees = Math64x61.sub(locked_capital, premia_with_fees);

        return (position_value = locked_and_premia_with_fees);
    } else {

        let locked_capital = Math64x61.mul(option_size, strike_price);
        let locked_and_premia_with_fees = Math64x61.sub(locked_capital, premia_with_fees);

        return (position_value = locked_and_premia_with_fees);
    }
}
