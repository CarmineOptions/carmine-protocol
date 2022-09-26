// Helper functions

%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le

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

struct Option {
    option_side: felt,
    maturity: felt,
    strike_price: felt,
    asset: felt,
}

func _get_premia_with_fees_for_position(option: Option, position_size: felt) -> (premia: felt){
    alloc_locals; 

    let side = option.option_side;
    let maturity = option.maturity;
    let strike_price = strike_price;
    let underlying_asset = option.asset;
    let option_size = position_size;
    let (option_type) = option_type.read();

    // 0) Get pool address
    let (pool_address) = pool_address_for_given_asset_and_option_type.read(
        underlying_asset,
        option_type
    );   

    // 1) Get current volatility
    let (current_volatility) = pool_volatility.read(maturity);

    // 2) Get price of underlying asset
    let (empiric_key) = get_empiric_key(underlying_asset);
    let (underlying_price) = empiric_median_price(empiric_key);

    // 3) Calculate new volatility, calculate trade volatilit
    let (current_pool_balance) = get_pool_available_balance(pool_address);
    // assert_nn_le(Math64x61.ONE, current_pool_balance);
    // assert_nn_le(option_size_in_pool_currency, current_pool_balance);

    let (_, trade_volatility) = get_new_volatility(
        current_volatility, option_size, option_type, side, underlying_price, current_pool_balance
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

    return (total_premia = total_premia);
}
