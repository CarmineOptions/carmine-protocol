// Wrapper for non viewed functions in contracts/option_pricing.cairo
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.option_pricing import std_normal_cdf, d1_d2

// wrapper for contracts.option_pricing.std_normal_cdf for purpose of unit testing
@view
func testable_std_normal_cdf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: felt
) -> (res: felt) {
    let (res) = std_normal_cdf(x);
    return (res=res);
}

// wrapper for contracts.option_pricing.d1_d2 for purpose of unit testing
@view
func testable_d1_d2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sigma: felt,
    time_till_maturity_annualized: felt,
    strike_price: felt,
    underlying_price: felt,
    risk_free_rate_annualized: felt,
) -> (d_1: felt, is_pos_d_1: felt, d_2: felt, is_pos_d_2: felt) {
    let (d_1, is_pos_d_1, d_2, is_pos_d_2) = d1_d2(
        sigma=sigma,
        time_till_maturity_annualized=time_till_maturity_annualized,
        strike_price=strike_price,
        underlying_price=underlying_price,
        risk_free_rate_annualized=risk_free_rate_annualized,
    );
    return (d_1=d_1, is_pos_d_1=is_pos_d_1, d_2=d_2, is_pos_d_2=is_pos_d_2);
}
