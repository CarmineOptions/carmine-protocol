// Contract that calculates Black-Scholes with Choudhury's approximation to std normal CDF
// https://www.hrpub.org/download/20140305/MS7-13401470.pdf.

%lang starknet


//
// @title Module for options pricing
// @notice Module with collection of functions that result in options being priced
// @dev In reality the AMM is not pricing options through Black-Scholes model, but uses the model
//      for price adjustments!!! This makes the standard problems of Black-Scholes model
//      not important
//

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import sign, assert_le, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le

// Third party imports. Was copy pasted to this repo.
from math64x61 import Math64x61



const HALF = 1152921504606846976;
const THREE = 6917529027641081856;
const EIGHT = 18446744073709551616;
const TEN = 23058430092136939520;
const INV_ROOT_OF_TWO_PI = 919898267902984507;
const CONST_A = 521120520082294833;
const CONST_B = 1475739525896764129;
const CONST_C = 760928193040519004;
const INV_EXP_TEN = 104685105675288;



// @notice Calculates 1/exp(x) for big x
// @dev Leverages the fact that 1/exp(x+a) = 1/(exp(x)*exp(a))
// @param x: number in Math64x61 form
// @return Returns 1/exp(x) in Math64x61 form
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

        let res = Math64x61.mul(INV_EXP_TEN, inv_exp_x_minus_ten);
        return (x=res);
    }
}


// @notice Calculates approximate value of standard normal CDF
// @dev The approximation works well between -8 and 8. Its not the best approximation out there,
//      but its not iterative, its simple to compute and works well on a wide range of values.
//      There is no need for perfect approximation since this is part of the Black-Scholes model
//      and that is used for updating prices.
// @param x: number in Math64x61 form
// @return Returns std normal cdf value in Math64x61 form
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

    // Max value of x for standard normal distribution function is currently 8, since after that, 
    // Math64x61 runs out of precision and this function returns only 0, which is sub-optimal
    with_attr error_message("option_pricing.std_normal_cdf received X value higher than 8") {
        // Only x < 8 is being checked and not -8 < x since this case is dealt with in the above
        // "if condition"
        assert_le(x, EIGHT);
    }

    local x_squared = Math64x61.mul(x, x);
    let x_squared_half = Math64x61.mul(x_squared, HALF);
    let (numerator) = inv_exp_big_x(x_squared_half);

    let denominator_b = Math64x61.mul(CONST_B, x);
    let denominator_a = Math64x61.add(CONST_A, denominator_b);
    let sqrt_den_part = Math64x61.sqrt(x_squared + THREE);
    let denominator_c = Math64x61.mul(CONST_C, sqrt_den_part);
    let denominator = Math64x61.add(denominator_a, denominator_c);

    let res_a = Math64x61.div(numerator, denominator);
    let res_b = Math64x61.mul(INV_ROOT_OF_TWO_PI, res_a);
    let res = Math64x61.sub(Math64x61.ONE, res_b);
    return (res=res);
}


// @notice Helper function
// @dev This is just "extracted" code from the main function so that it wouldn't be really long
//      "noondle".
// @param is_frac: bool that determines whether the price to strike is actually price to strike
//      or strike to price
// @param ln_price_to_strike: ln(price/strike) or ln(strike/price) depending on "is_frac"
// @param risk_plus_sigma_squared_half_time:
// @return Returns values that are needed for further computation.
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


// @notice Helper function
// @dev This is just "extracted" code from the main function so that it wouldn't be really long
//      "noondle".
// @param is_pos_d1: "intermeidary" value needed inside of the Black-Scholes
// @param d_1: "intermeidary" value needed inside of the Black-Scholes
// @param denominator: "intermeidary" value needed inside of the Black-Scholes
// @return Returns values that are needed for further computation.
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


// @notice Calculates D_1 and D_2 for the Black-Scholes model
// @param sigma: sigma, used as volatility... 80% volatility is represented as 0.8*2**61
// @param time_till_maturity_annualized: Annualized time till maturity represented as Math64x61
// @param strike_price: strike in Math64x61
// @param underlying_price: price of underlying asset in Math64x61
// @param risk_free_rate_annualized: risk free rate that is annualized
// @return Returns D1 and D2 needed in the Black Scholes model and their sign
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

    let (sigma_squared_half, _) = unsigned_div_rem(sigma_squared, 2);
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


// @notice Calculates STD normal CDF
// @param d: d value (either d_1 or d_2) in the BS model
// @param is_pos: sign of d
// @return Returns the std normal CDF value of D
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


// @notice Calculates value for Black Scholes
// @param sigma: sigma, used as volatility... 80% volatility is represented as 0.8*2**61
// @param time_till_maturity_annualized: Annualized time till maturity represented as Math64x61
// @param strike_price: strike in Math64x61
// @param underlying_price: price of underlying asset in Math64x61
// @param risk_free_rate_annualized: risk free rate that is annualized
// @return Returns call and put option premium
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
    
    with_attr error_message("Black scholes function failed when calculating d_1"){
        let (normal_d_1) = adjusted_std_normal_cdf(d_1, is_pos_d_1);
    }
    with_attr error_message("Black scholes function failed when calculating d_2"){
        let (normal_d_2) = adjusted_std_normal_cdf(d_2, is_pos_d_2);
    }
    
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
