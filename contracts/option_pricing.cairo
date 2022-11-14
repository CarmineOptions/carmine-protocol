// Contract that calculates Black-Scholes with Choudhury's approximation to std normal CDF
// https://www.hrpub.org/download/20140305/MS7-13401470.pdf.

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import sign, assert_le
from starkware.cairo.common.math_cmp import is_le

// Third party imports. Was copy pasted to this repo.
from math64x61 import Math64x61



const HALF = 1152921504606846976;
const THREE = 6917529027641081856;
const EIGHT = 18446744073709551616;
const TEN = 23058430092136939520;
// const two_pi = 14488038916154230748;
const inv_root_of_two_pi = 919898267902984507;
const const_a = 521120520082294833;
const const_b = 1475739525896764129;
const const_c = 760928193040519004;
const inv_exp_ten = 104685105675288;



func inv_exp_big_x{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(x: felt) -> (
    x: felt
) {
    // Calculates 1/exp(x) for big x
    // since 1/exp(x+a) = 1/(exp(x)*exp(a))

    alloc_locals;

    let is_le_ten = is_le(x, TEN);
    if (is_le_ten == 1) {
        let exp_x = Math64x61.exp(x);
        let res = Math64x61.div(Math64x61.ONE, exp_x);
        return (x=res);
    } else {
        let x_minus_ten = Math64x61.sub(x, TEN);
        let (inv_exp_x_minus_ten) = inv_exp_big_x(x_minus_ten);

        let res = Math64x61.mul(inv_exp_ten, inv_exp_x_minus_ten);
        return (x=res);
    }
}


// Calculates approximate value of standard normal CDF
func std_normal_cdf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(x: felt) -> (
    res: felt
) {
    // Expects the input x to be in Math64x61.FRACT_PART units. Ie for 0.5 pass in 0.5*Math64x61.FRACT_PART.
    // Returns the result of std normal cdf in Math64x61.FRACT_PART units.

    alloc_locals;

    let sign_value = sign(x);
    if (sign_value == -1) {
        let (dist_symmetric_value) = std_normal_cdf(-x);
        let res = Math64x61.sub(Math64x61.ONE, dist_symmetric_value);
        return (res=res);
    }

    with_attr error_message("option_pricing.std_normal_cdf received X value higher than 8") {
        assert_le(x, EIGHT);
    }

    local x_squared = Math64x61.mul(x, x);
    let x_squared_half = Math64x61.mul(x_squared, HALF);
    let (numerator) = inv_exp_big_x(x_squared_half);

    let denominator_b = Math64x61.mul(const_b, x);
    let denominator_a = Math64x61.add(const_a, denominator_b);
    let sqrt_den_part = Math64x61.sqrt(x_squared + THREE);
    let denominator_c = Math64x61.mul(const_c, sqrt_den_part);
    let denominator = Math64x61.add(denominator_a, denominator_c);

    let res_a = Math64x61.div(numerator, denominator);
    let res_b = Math64x61.mul(inv_root_of_two_pi, res_a);
    let res = Math64x61.sub(Math64x61.ONE, res_b);
    return (res=res);
}

func _get_d1_d2_numerator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    is_frac: felt, ln_price_to_strike: felt, risk_plus_sigma_squared_half_time: felt
) -> (numerator: felt, is_pos_d_1: felt) {
    if (is_frac == 1) {
        // ln_price_to_strike < 0 (not stored as negative, but above the "let (div) = Math6..." had to be used
        // to not overflow
        // risk_plus_sigma_squared_half_time > 0
        let is_ln_smaller = is_le(ln_price_to_strike, risk_plus_sigma_squared_half_time - 1);
        if (is_ln_smaller == 1) {
            let numerator = Math64x61.sub(risk_plus_sigma_squared_half_time, ln_price_to_strike);
            let is_pos_d_1 = 1;
            return (numerator=numerator, is_pos_d_1=is_pos_d_1);
        } else {
            let numerator = Math64x61.sub(ln_price_to_strike, risk_plus_sigma_squared_half_time);
            let is_pos_d_1 = 0;
            return (numerator=numerator, is_pos_d_1=is_pos_d_1);
        }
    } else {
        // both ln_price_to_strike, risk_plus_sigma_squared_half_time are positive
        let numerator = Math64x61.add(ln_price_to_strike, risk_plus_sigma_squared_half_time);
        let is_pos_d_1 = 1;
        return (numerator=numerator, is_pos_d_1=is_pos_d_1);
    }
}

func _get_d1_d2_d_2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    is_pos_d1: felt, d_1: felt, denominator: felt
) -> (d_2: felt, is_pos_d_2: felt) {
    if (is_pos_d1 == 0) {
        let d_2 = Math64x61.add(d_1, denominator);
        return (d_2=d_2, is_pos_d_2=0);
    } else {
        let is_pos_d_2 = is_le(denominator, d_1 - 1);
        if (is_pos_d_2 == 1) {
            let d_2 = Math64x61.sub(d_1, denominator);
            return (d_2=d_2, is_pos_d_2=is_pos_d_2);
        } else {
            let d_2 = Math64x61.sub(denominator, d_1);
            return (d_2=d_2, is_pos_d_2=is_pos_d_2);
        }
    }
}

// Calculates D_1 and D_2 for the Black-Scholes model
func d1_d2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sigma: felt,
    time_till_maturity_annualized: felt,
    strike_price: felt,
    underlying_price: felt,
    risk_free_rate_annualized: felt,
) -> (d_1: felt, is_pos_d_1: felt, d_2: felt, is_pos_d_2: felt) {
    // ALL OF THE INPUTS ARE FIXED POINT VALUE (ie they went through the Math64x61.fromFelt)

    // d_1 = \frac{1}{\sigma\sqrt{T-t}}[ln(\frac{S_t}{K})+(r+\frac{\sigma^2}{2})(T-t)]
    // d_2=d_1-\sigma\sqrt{T-t}

    alloc_locals;

    let sqrt_time_till_maturity_annualized = Math64x61.sqrt(time_till_maturity_annualized);
    let sigma_squared = Math64x61.mul(sigma, sigma);
    let sigma_squared_half = Math64x61.mul(sigma_squared, HALF);
    let risk_plus_sigma_squared_half = Math64x61.add(
        risk_free_rate_annualized, sigma_squared_half
    );

    let price_to_strike = Math64x61.div(underlying_price, strike_price);

    // if price_to_strike < 1 -> ln_price_to_strike < 0...
    let is_frac = is_le(price_to_strike, Math64x61.FRACT_PART - 1);
    if (is_frac == 1) {
        let div = Math64x61.div(Math64x61.ONE, price_to_strike);
        let ln_price_to_strike = Math64x61.ln(div);
    } else {
        let ln_price_to_strike = Math64x61.ln(price_to_strike);
    }

    let risk_plus_sigma_squared_half_time = Math64x61.mul(
        risk_plus_sigma_squared_half, time_till_maturity_annualized
    );

    let (numerator, is_pos_d1) = _get_d1_d2_numerator(
        is_frac, ln_price_to_strike, risk_plus_sigma_squared_half_time
    );

    let denominator = Math64x61.mul(sigma, sqrt_time_till_maturity_annualized);

    let d_1 = Math64x61.div(numerator, denominator);

    let (d_2, is_pos_d_2) = _get_d1_d2_d_2(is_pos_d1, d_1, denominator);

    return (d_1=d_1, is_pos_d_1=is_pos_d1, d_2=d_2, is_pos_d_2=is_pos_d_2);
}

func adjusted_std_normal_cdf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    d: felt, is_pos: felt
) -> (res: felt) {
    if (is_pos == 0) {
        let (d_) = std_normal_cdf(d);
        let normal_d = Math64x61.sub(Math64x61.ONE, d_);
        return (res=normal_d);
    } else {
        let (normal_d) = std_normal_cdf(d);
        return (res=normal_d);
    }
}

// Calculates value for Black Scholes
@view
func black_scholes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sigma: felt,
    time_till_maturity_annualized: felt,
    strike_price: felt,
    underlying_price: felt,
    risk_free_rate_annualized: felt,
) -> (call_premia: felt, put_premia: felt) {
    // C(S_t, t) = N(d_1)S_t - N(d_2)Ke^{-r(T-t)}
    // P(S_t, t) = Ke^{-r(T-t)}-S_t+C(S_t, t)

    alloc_locals;

    let risk_time_till_maturity = Math64x61.mul(
        risk_free_rate_annualized, time_till_maturity_annualized
    );
    let e_risk_time_till_maturity = Math64x61.exp(risk_time_till_maturity);
    let e_neg_risk_time_till_maturity = Math64x61.div(Math64x61.ONE, e_risk_time_till_maturity);
    let strike_e_neg_risk_time_till_maturity = Math64x61.mul(
        strike_price, e_neg_risk_time_till_maturity
    );

    let (d_1, is_pos_d_1, d_2, is_pos_d_2) = d1_d2(
        sigma,
        time_till_maturity_annualized,
        strike_price,
        underlying_price,
        risk_free_rate_annualized,
    );

    let (normal_d_1) = adjusted_std_normal_cdf(d_1, is_pos_d_1);
    let (normal_d_2) = adjusted_std_normal_cdf(d_2, is_pos_d_2);

    let normal_d_1_underlying_price = Math64x61.mul(normal_d_1, underlying_price);
    let normal_d_2_strike_e_neg_risk_time_till_maturity = Math64x61.mul(
        normal_d_2, strike_e_neg_risk_time_till_maturity
    );

    let call_option_value = Math64x61.sub(
        normal_d_1_underlying_price, normal_d_2_strike_e_neg_risk_time_till_maturity
    );

    let neg_underlying_price_call_value = Math64x61.sub(call_option_value, underlying_price);
    let put_option_value = Math64x61.add(
        strike_e_neg_risk_time_till_maturity, neg_underlying_price_call_value
    );

    return (call_premia=call_option_value, put_premia=put_option_value);
}
