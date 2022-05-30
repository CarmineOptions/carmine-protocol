# Contract that calculates Black-Scholes with Choudhury's approximation to std normal CDF
# https://www.hrpub.org/download/20140305/MS7-13401470.pdf.

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import sign
from starkware.cairo.common.math_cmp import is_le

# Third party imports. Was copy pasted to this repo.
from contracts.Math64x61 import (
    Math64x61_fromFelt,
    Math64x61_toFelt,
    Math64x61_exp,
    Math64x61_ln,
    Math64x61_sqrt,
    Math64x61_mul,
    Math64x61_div,
    Math64x61_add,
    Math64x61_sub,
    Math64x61_FRACT_PART,
    Math64x61_ONE
)


const INPUT_UNIT = 10**8


func _decimal_thousandth{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(x: felt) -> (
    res : felt
):
    let (cons) = Math64x61_fromFelt(x)
    let (thousand) = Math64x61_fromFelt(1000)
    let (res) = Math64x61_div(cons, thousand)
    return (res)
end

func _get_pi{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    res : felt
):
    # Can't have it outside, since it requires "range_check_ptr"
    # 3.14159265358979
    let (PI_a) = Math64x61_fromFelt(314159265358979)
    let (PI_b) = Math64x61_fromFelt(10**14)
    let (PI) = Math64x61_div(PI_a, PI_b)
    return (PI)
end

# Calculates approximate value of standard normal CDF
@view
func std_normal_cdf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(x: felt) -> (
    res : felt, base: felt
):
    # Expects the input x to be in INPUT_UNIT units. Ie for 0.5 pass in 0.5*INPUT_UNIT.
    # Returns the result of std normal cdf and the base that it has to be divided by.
    # The base is equivalent to INPUT_UNIT.

    alloc_locals

    # Constants required in the "initial if".
    let (base) = Math64x61_fromFelt(INPUT_UNIT)
    let (MINUS_ONE) = Math64x61_fromFelt(-1)

    let (sign_value) = sign(x)
    if sign_value == -1:
        let (dist_symmetric_value, _) = std_normal_cdf(-x)
        let (dist_symmetric_value_) = Math64x61_fromFelt(dist_symmetric_value)
        let (neg_dist_symmetric_value_) = Math64x61_mul(dist_symmetric_value_, MINUS_ONE)
        let (res) = Math64x61_add(base, neg_dist_symmetric_value_)
        let (res_felt) = Math64x61_toFelt(res)
        let (base_felt) = Math64x61_toFelt(base)
        return (res=res_felt, base=base_felt)
    end

    # Input adjustment
    #let (input_unadjusted) = Math64x61_fromFelt(x)
    #let (input) = Math64x61_div(input_unadjusted, base)
    let input = x

    # Constants required in the "rest of the code".
    let (PI) = _get_pi()

    # TODO: check following
    # Math64x61_fromFelt is used to make sure that the multiplications (and etc) below do now overflow.
    # But I'm far from sure that without it they would overflow and with this they won't.
    let (ONE) = Math64x61_fromFelt(1)
    let (TWO) = Math64x61_fromFelt(2)
    let (THREE) = Math64x61_fromFelt(3)
    let (two_pi) = Math64x61_mul(TWO, PI)
    let (root_of_two_pi) = Math64x61_sqrt(two_pi)
    let (inv_root_of_two_pi) = Math64x61_div(ONE, root_of_two_pi)
    let (CDF_CONST) = Math64x61_mul(MINUS_ONE, inv_root_of_two_pi)
    let (const_a) = _decimal_thousandth(226)
    let (const_b) = _decimal_thousandth(640)
    let (const_c) = _decimal_thousandth(330)

    let (x_squared) = Math64x61_mul(input, input)
    let (x_squared_half) = Math64x61_div(x_squared, TWO)
    let (minus_x_squared_half) = Math64x61_mul(MINUS_ONE, x_squared_half)
    let (numerator) = Math64x61_exp(minus_x_squared_half)

    let (denominator_b) = Math64x61_mul(const_b, input)
    let (denominator_a) = Math64x61_add(const_a, denominator_b)
    let (sqrt_den_part) = Math64x61_sqrt(x_squared + THREE)
    let (denominator_c) = Math64x61_mul(const_c, sqrt_den_part)
    let (denominator) = Math64x61_add(denominator_a, denominator_c)

    let (res_a) = Math64x61_div(numerator, denominator)
    let (res_b) = Math64x61_mul(CDF_CONST, res_a)
    let (res) = Math64x61_add(ONE, res_b)

    let (res_based) = Math64x61_mul(res, base)
    let (res_based_felt) = Math64x61_toFelt(res_based)
    let (base_felt) = Math64x61_toFelt(base)
    return (res=res_based_felt, base=base_felt)
end

func _get_d1_d2_numerator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    is_frac: felt,
    ln_price_to_strike: felt,
    risk_plus_sigma_squared_half_time: felt
) -> (
    numerator : felt,
    is_pos_d_1: felt
):
    if is_frac == 1:
        # ln_price_to_strike < 0 (not stored as negative, but above the "let (div) = Math6..." had to be used
        # to not overflow
        # risk_plus_sigma_squared_half_time > 0
        let (is_ln_smaller) = is_le(ln_price_to_strike, risk_plus_sigma_squared_half_time - 1)
        if is_ln_smaller == 1:
            let (numerator) = Math64x61_sub(risk_plus_sigma_squared_half_time, ln_price_to_strike)
            let is_pos_d_1 = 1
            return (numerator=numerator, is_pos_d_1=is_pos_d_1)
        else:
            let (numerator) = Math64x61_sub(ln_price_to_strike, risk_plus_sigma_squared_half_time)
            let is_pos_d_1 = 0
            return (numerator=numerator, is_pos_d_1=is_pos_d_1)
        end
    else:
        # both ln_price_to_strike, risk_plus_sigma_squared_half_time are positive
        let (numerator) = Math64x61_add(ln_price_to_strike, risk_plus_sigma_squared_half_time)
        let is_pos_d_1 = 1
        return (numerator=numerator, is_pos_d_1=is_pos_d_1)
    end
end

func _get_d1_d2_d_2{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    is_pos_d1: felt,
    d_1: felt,
    denominator: felt
) -> (
    d_2: felt,
    is_pos_d_2: felt
):
    if is_pos_d1 == 0:
        let (d_2) = Math64x61_add(d_1, denominator)
        return (d_2=d_2, is_pos_d_2=0)
    else:
        let (is_pos_d_2) = is_le(denominator, d_1 - 1)
        if is_pos_d_2 == 1:
            let (d_2) = Math64x61_sub(d_1, denominator)
            return (d_2=d_2, is_pos_d_2=is_pos_d_2)
        else:
            let (d_2) = Math64x61_sub(denominator, d_1)
            return (d_2=d_2, is_pos_d_2=is_pos_d_2)
        end
    end
end

func d1_d2{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sigma: felt,
    time_till_maturity_annualized: felt,
    strike_price: felt,
    underlying_price: felt,
    risk_free_rate_annualized: felt
) -> (
    d_1: felt,
    is_pos_d_1: felt,
    d_2: felt,
    is_pos_d_2: felt
):
    # ALL OF THE INPUTS ARE FIXED POINT VALUE (ie they went through the Math64x61_fromFelt)

    # d_1 = \frac{1}{\sigma\sqrt{T-t}}[ln(\frac{S_t}{K})+(r+\frac{\sigma^2}{2})(T-t)]
    # d_2=d_1-\sigma\sqrt{T-t}

    alloc_locals

    let (TWO) = Math64x61_fromFelt(2)

    let (sqrt_time_till_maturity_annualized) = Math64x61_sqrt(time_till_maturity_annualized)
    let (sigma_squared) = Math64x61_mul(sigma, sigma)
    let (sigma_squared_half) = Math64x61_div(sigma_squared, TWO)
    let (risk_plus_sigma_squared_half) = Math64x61_add(risk_free_rate_annualized, sigma_squared_half)

    let (price_to_strike) = Math64x61_div(underlying_price, strike_price)

    # if price_to_strike < 1 -> ln_price_to_strike < 0...
    let (is_frac) = is_le(price_to_strike, Math64x61_FRACT_PART - 1)
    if is_frac == 1:
        let (div) = Math64x61_div(Math64x61_ONE, price_to_strike)
        let (ln_price_to_strike) = Math64x61_ln(div)
    else:
        let (ln_price_to_strike) = Math64x61_ln(price_to_strike)
    end

    let (risk_plus_sigma_squared_half_time) = Math64x61_mul(risk_plus_sigma_squared_half, time_till_maturity_annualized)

    let (numerator, is_pos_d1) = _get_d1_d2_numerator(
        is_frac,
        ln_price_to_strike,
        risk_plus_sigma_squared_half_time
    )

    let (denominator) = Math64x61_mul(sigma, sqrt_time_till_maturity_annualized)

    let (d_1) = Math64x61_div(numerator, denominator)

    let (d_2, is_pos_d_2) = _get_d1_d2_d_2(is_pos_d1, d_1, denominator)

    return (d_1=d_1, is_pos_d_1=is_pos_d1, d_2=d_2, is_pos_d_2=is_pos_d_2)
end

@view
func testable_d1_d2{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _sigma: felt,
    _time_till_maturity_annualized: felt,
    _strike_price: felt,
    _underlying_price: felt,
    _risk_free_rate_annualized: felt
) -> (
    d_1 : felt,
    is_pos_d_1: felt,
    d_2: felt,
    is_pos_d_2: felt
):
    # wrapper for d1_d2 function for purpose of testing

    alloc_locals

    let (base) = Math64x61_fromFelt(INPUT_UNIT)
    let (sigma_) = Math64x61_fromFelt(_sigma)
    let (time_till_maturity_annualized_) = Math64x61_fromFelt(_time_till_maturity_annualized)
    let (strike_price_) = Math64x61_fromFelt(_strike_price)
    let (underlying_price_) = Math64x61_fromFelt(_underlying_price)
    let (risk_free_rate_annualized_) = Math64x61_fromFelt(_risk_free_rate_annualized)

    let (sigma) = Math64x61_div(sigma_, base)
    let (time_till_maturity_annualized) = Math64x61_div(time_till_maturity_annualized_, base)
    let (strike_price) = Math64x61_div(strike_price_, base)
    let (underlying_price) = Math64x61_div(underlying_price_, base)
    let (risk_free_rate_annualized) = Math64x61_div(risk_free_rate_annualized_, base)

    let (d_1, is_pos_d_1, d_2, is_pos_d_2) = d1_d2(
        sigma,
        time_till_maturity_annualized,
        strike_price,
        underlying_price,
        risk_free_rate_annualized
    )

    let (d_1_) = Math64x61_mul(d_1, base)
    let (d_2_) = Math64x61_mul(d_2, base)
    let (d_1__) = Math64x61_toFelt(d_1_)
    let (d_2__) = Math64x61_toFelt(d_2_)
    return (d_1=d_1__, is_pos_d_1=is_pos_d_1, d_2=d_2__, is_pos_d_2=is_pos_d_2)
end

# Calculates approximate value for Black Scholes
@view
func black_scholes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sigma: felt,
    time_till_maturity_annualized: felt,
    strike_price: felt,
    underlying_price: felt,
    risk_free_rate_annualized: felt
) -> (
    call_premia: felt,
    put_premia: felt,
    base : felt
):
    # C(S_t, t) = N(d_1)S_t - N(d_2)Ke^{-r(T-t)}
    # P(S_t, t) = Ke^{-r(T-t)}-S_t+C(S_t, t)

    alloc_locals

    let (base) = Math64x61_fromFelt(INPUT_UNIT)

    let (sigma__) = Math64x61_fromFelt(sigma)
    let (sigma_) = Math64x61_div(sigma__, base)
    let (time_till_maturity_annualized__) = Math64x61_fromFelt(time_till_maturity_annualized)
    let (time_till_maturity_annualized_) = Math64x61_div(time_till_maturity_annualized__, base)
    let (strike_price__) = Math64x61_fromFelt(strike_price)
    let (strike_price_) = Math64x61_div(strike_price__, base)
    let (underlying_price__) = Math64x61_fromFelt(underlying_price)
    let (underlying_price_) = Math64x61_div(underlying_price__, base)
    let (risk_free_rate_annualized__) = Math64x61_fromFelt(risk_free_rate_annualized)
    let (risk_free_rate_annualized_) = Math64x61_div(risk_free_rate_annualized__, base)

    let (risk_time_till_maturity) = Math64x61_mul(risk_free_rate_annualized_, time_till_maturity_annualized_)
    let (MINUS_ONE) = Math64x61_fromFelt(-1)
    let (neg_risk_time_till_maturity) = Math64x61_mul(MINUS_ONE, risk_time_till_maturity)
    let (e_neg_risk_time_till_maturity) = Math64x61_exp(neg_risk_time_till_maturity)
    let (strike_e_neg_risk_time_till_maturity) = Math64x61_mul(strike_price_, e_neg_risk_time_till_maturity)

    let (d_1, is_pos_d_1, d_2, is_pos_d_2) = d1_d2(
        sigma_,
        time_till_maturity_annualized_,
        strike_price_,
        underlying_price_,
        risk_free_rate_annualized_
    )

    let (normal_d_1, _) = std_normal_cdf(d_1)
    let (normal_d_2, _) = std_normal_cdf(d_2)

    let (normal_d_1_underlying_price) = Math64x61_mul(normal_d_1, underlying_price_)
    let (normal_d_2_strike_e_neg_risk_time_till_maturity) = Math64x61_mul(
        normal_d_2,
        strike_e_neg_risk_time_till_maturity
    )
    let (neg_normal_d_2_strike_e_neg_risk_time_till_maturity) = Math64x61_mul(
        MINUS_ONE,
        normal_d_2_strike_e_neg_risk_time_till_maturity
    )

    let (call_option_value) = Math64x61_add(
        normal_d_1_underlying_price,
        neg_normal_d_2_strike_e_neg_risk_time_till_maturity
    )

    let (neg_underlying_price) = Math64x61_mul(MINUS_ONE, underlying_price_)
    let (neg_underlying_price_call_value) = Math64x61_add(neg_underlying_price, call_option_value)
    let (put_option_value) = Math64x61_add(strike_e_neg_risk_time_till_maturity, neg_underlying_price_call_value)

    let (call_premia_based) = Math64x61_mul(call_option_value, base)
    let (put_premia_based) = Math64x61_mul(put_option_value, base)
    let (call_premia) = Math64x61_toFelt(call_premia_based)
    let (put_premia) = Math64x61_toFelt(put_premia_based)

    return (call_premia=call_premia, put_premia=put_premia, base=base)

    #let (sigma___) = Math64x61_toFelt(sigma__)
    #return (call_premia=sigma___, put_premia=sigma___, base=sigma___)
end
