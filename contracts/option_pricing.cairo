# Contract that calculates Black-Scholes with Choudhury's approximation to std normal CDF
# https://www.hrpub.org/download/20140305/MS7-13401470.pdf.

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import sign
from starkware.cairo.common.math_cmp import is_le

# Third party imports. Was copy pasted to this repo.
from contracts.Math64x61 import (
    Math64x61_fromFelt,
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

func inv_exp_big_x{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(x: felt) -> (x: felt):
    # Calculates 1/exp(x) for big x
    # since 1/exp(x+a) = 1/(exp(x)*exp(a))

    alloc_locals

    let (ten) = Math64x61_fromFelt(10)

    let (is_le_ten) = is_le(x, ten)
    if is_le_ten == 1:
        let (exp_x) = Math64x61_exp(x)
        let (res) = Math64x61_div(Math64x61_ONE, exp_x)
        return (x=res)
    else:
        let (x_minus_ten) = Math64x61_sub(x, ten)
        let (inv_exp_x_minus_ten) = inv_exp_big_x(x_minus_ten)

        let (exp_ten) = Math64x61_exp(ten)
        let (inv_exp_ten) = Math64x61_div(Math64x61_ONE, exp_ten)

        let (res) = Math64x61_mul(inv_exp_ten, inv_exp_x_minus_ten)
        return (x=res)
    end
end

# Calculates approximate value of standard normal CDF
func std_normal_cdf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(x: felt) -> (
    res : felt
):
    # Expects the input x to be in Math64x61_FRACT_PART units. Ie for 0.5 pass in 0.5*Math64x61_FRACT_PART.
    # Returns the result of std normal cdf in Math64x61_FRACT_PART units.

    alloc_locals

    let (sign_value) = sign(x)
    if sign_value == -1:
        let (dist_symmetric_value) = std_normal_cdf(-x)
        let (res) = Math64x61_sub(Math64x61_ONE, dist_symmetric_value)
        return (res=res)
    end

    # Constants required in the "rest of the code".
    let (PI) = _get_pi()

    # TODO: check following
    # Math64x61_fromFelt is used to make sure that the multiplications (and etc) below do now overflow.
    # But I'm far from sure that without it they would overflow and with this they won't.
    let (TWO) = Math64x61_fromFelt(2)
    let (THREE) = Math64x61_fromFelt(3)
    let (two_pi) = Math64x61_mul(TWO, PI)
    let (root_of_two_pi) = Math64x61_sqrt(two_pi)
    let (inv_root_of_two_pi) = Math64x61_div(Math64x61_ONE, root_of_two_pi)
    let (const_a) = _decimal_thousandth(226)
    let (const_b) = _decimal_thousandth(640)
    let (const_c) = _decimal_thousandth(330)

    let (x_squared) = Math64x61_mul(x, x)
    let (x_squared_half) = Math64x61_div(x_squared, TWO)
    let (numerator) = inv_exp_big_x(x_squared_half)

    let (denominator_b) = Math64x61_mul(const_b, x)
    let (denominator_a) = Math64x61_add(const_a, denominator_b)
    let (x_squared) = Math64x61_mul(x, x)
    let (sqrt_den_part) = Math64x61_sqrt(x_squared + THREE)
    let (denominator_c) = Math64x61_mul(const_c, sqrt_den_part)
    let (denominator) = Math64x61_add(denominator_a, denominator_c)

    let (res_a) = Math64x61_div(numerator, denominator)
    let (res_b) = Math64x61_mul(inv_root_of_two_pi, res_a)
    let (res) = Math64x61_sub(Math64x61_ONE, res_b)
    return (res=res)
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

# Calculates D_1 and D_2 for the Black-Scholes model
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

func adjusted_std_normal_cdf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    d: felt,
    is_pos: felt
) -> (
    res: felt
):
    if is_pos == 0:
        let (d_) = std_normal_cdf(d)
        let (normal_d) = Math64x61_sub(Math64x61_ONE, d_)
        return (res=normal_d)
    else:
        let (normal_d) = std_normal_cdf(d)
        return (res=normal_d)
    end
end

# Calculates value for Black Scholes
@view
func black_scholes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sigma: felt,
    time_till_maturity_annualized: felt,
    strike_price: felt,
    underlying_price: felt,
    risk_free_rate_annualized: felt
) -> (
    call_premia: felt,
    put_premia: felt
):
    # C(S_t, t) = N(d_1)S_t - N(d_2)Ke^{-r(T-t)}
    # P(S_t, t) = Ke^{-r(T-t)}-S_t+C(S_t, t)

    alloc_locals

    let (risk_time_till_maturity) = Math64x61_mul(risk_free_rate_annualized, time_till_maturity_annualized)
    let (e_risk_time_till_maturity) = Math64x61_exp(risk_time_till_maturity)
    let (e_neg_risk_time_till_maturity) = Math64x61_div(Math64x61_ONE, e_risk_time_till_maturity)
    let (strike_e_neg_risk_time_till_maturity) = Math64x61_mul(strike_price, e_neg_risk_time_till_maturity)

    let (d_1, is_pos_d_1, d_2, is_pos_d_2) = d1_d2(
        sigma,
        time_till_maturity_annualized,
        strike_price,
        underlying_price,
        risk_free_rate_annualized
    )

    let (normal_d_1) = adjusted_std_normal_cdf(d_1, is_pos_d_1)
    let (normal_d_2) = adjusted_std_normal_cdf(d_2, is_pos_d_2)

    let (normal_d_1_underlying_price) = Math64x61_mul(normal_d_1, underlying_price)
    let (normal_d_2_strike_e_neg_risk_time_till_maturity) = Math64x61_mul(
        normal_d_2,
        strike_e_neg_risk_time_till_maturity
    )

    let (call_option_value) = Math64x61_sub(
        normal_d_1_underlying_price,
        normal_d_2_strike_e_neg_risk_time_till_maturity
    )

    let (neg_underlying_price_call_value) = Math64x61_sub(call_option_value, underlying_price)
    let (put_option_value) = Math64x61_add(strike_e_neg_risk_time_till_maturity, neg_underlying_price_call_value)

    return (call_premia=call_option_value, put_premia=put_option_value)
end
