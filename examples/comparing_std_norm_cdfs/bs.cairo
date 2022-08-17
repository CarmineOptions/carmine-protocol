# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.math_cmp import (
    is_nn, is_le
)
from starkware.cairo.common.math import (
    abs_value, sqrt, assert_le, assert_250_bit
)

from starkware.cairo.common.pow import (
    pow
)
from safe_math import (
    safe_div, multiply_decimal_round_precise, divide_decimal_round_precise
)

const RC_BOUND = 2 ** 128
const DIV_BOUND = 170141183460469231731687303715884105728  # (2 ** 128) // 2
const HIGH_PRECISION = 10 ** 27
const HIGH_PRECISION_DIV_10 = 10 ** 26
const HIGH_PRECISION_TIMES_10 = 10 ** 28
const PRECISION = 10 ** 18

const MIN_EXP = -64 * HIGH_PRECISION
const MAX_EXP = 100 * HIGH_PRECISION
const SQRT_TWOPI = 2506628274631000502415765285
const LN_2_PRECISE = 693147180559945309417232122
const MIN_CDF_STD_DIST_INPUT = HIGH_PRECISION_DIV_10 * -45  # -4.5 
const MAX_CDF_STD_DIST_INPUT = HIGH_PRECISION_TIMES_10

const MIN_T_ANNUALISED = 31709791983764586504
const MIN_VOLATILITY = 10 ** 23

# assumes that [0, 2**250) are +ve
func check_input_sanity{range_check_ptr}(
        tAnnualised: felt,
		volatility: felt,
		spot: felt,
		strike: felt
    ):
    assert_250_bit(tAnnualised)
    assert_250_bit(volatility)
    assert_250_bit(spot)
    assert_250_bit(strike)
    return()
end

func _ln_helper{range_check_ptr}(x: felt, last_v: felt) -> (v: felt, break: felt):

    let (exp_v: felt) = exp(last_v)
    let x_sub_e: felt = x - exp_v
    let x_plus_e: felt = x + exp_v
    let s_div: felt = divide_decimal_round_precise(x_sub_e * 2, x_plus_e)
    let v: felt = last_v + s_div

    # check eq
    let is_neq = last_v - v
    if is_neq == 0:
        return (v, 1)
    else:
        return (v, 0)
    end

end

# ln with halley's method (I think this is more accurate than ln_with_hints)
@external
func ln{range_check_ptr}(value: felt) -> (res: felt):

    let (v, b) = _ln_helper(value, 0)
    if b == 1:
        return (v)
    end
    let (v, b) = _ln_helper(value, v)
    if b == 1:
        return (v)
    end
    let (v, b) = _ln_helper(value, v)
    if b == 1:
        return (v)
    end
    let (v, b) = _ln_helper(value, v)
    if b == 1:
        return (v)
    end
    let (v, b) = _ln_helper(value, v)
    if b == 1:
        return (v)
    end
    let (v, b) = _ln_helper(value, v)
    if b == 1:
        return (v)
    end
    let (v, b) = _ln_helper(value, v)
    if b == 1:
        return (v)
    end
    let (v, b) = _ln_helper(value, v)
    if b == 1:
        return (v)
    end

    return (v)

end

@external
func _exp_helper{range_check_ptr}(last_t:felt, r: felt, i: felt) -> (t: felt, break: felt):
    alloc_locals

    let (ri, _) = safe_div(r, i)
    let ri_times_last_t: felt = multiply_decimal_round_precise(ri, last_t)
    let t: felt = ri_times_last_t + HIGH_PRECISION

    # check eq
    let is_neq = t - last_t
    if is_neq == 0:
        return (t, 1)
    else:
        return (t, 0)
    end
end

@external
func _exp{range_check_ptr}(x: felt) -> (res: felt):
    alloc_locals

    if x == 0:
        return (HIGH_PRECISION)
    end

    # this checks for -ve x as well
    assert_le(x, MAX_EXP)

    # r
    let k: felt = divide_decimal_round_precise(x, LN_2_PRECISE)
    let (local k_unprecise, _ ) = safe_div(k, HIGH_PRECISION)
    let (local p: felt) = pow(2, k_unprecise)
    let k_unprecise_mul_ln: felt = k_unprecise * LN_2_PRECISE
    local r: felt = x - k_unprecise_mul_ln

    # iterate
    let (t, b) = _exp_helper(HIGH_PRECISION, r, 16)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 15)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 14)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 13)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 12)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 11)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 10)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 9)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 8)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 7)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 6)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 5)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 4)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 3)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 2)
    if b == 1:
        return (p * t)
    end
    let (t, b) = _exp_helper(t, r, 1)
    if b == 1:
        return (p * t)
    end

    return (p*t)

end

@external
func exp{range_check_ptr}(x: felt) -> (res: felt):
    let x_nn: felt = is_nn(x)
    if x_nn == 1:
        let (res: felt) = _exp(x)
        return (res)
    end

    let x_less_min: felt = is_le(x, MIN_EXP-1)
    if x_less_min == 1:
        return (0)
    end

    let (inter_res: felt) = _exp(x*-1)
    let (res: felt) = divide_decimal_round_precise(HIGH_PRECISION, inter_res)
    return (res)
end


@external
func sqrt_precise{
        range_check_ptr
    }(value: felt) -> (root: felt):
    let value_times_precision: felt = value * HIGH_PRECISION
    let root: felt = sqrt(value_times_precision)
    return(root)
end

@external
func std_normal{
        range_check_ptr
    }(x: felt) -> (res: felt):
    let (x_div_2, _) = safe_div(x, 2)
    let (x_and_half) = multiply_decimal_round_precise(x, x_div_2)
    let (x_exp) = exp(-1 * x_and_half)
    let (res) = divide_decimal_round_precise(x_exp, SQRT_TWOPI)
    return(res)
end

func _std_normal_cdf_prob_helper{
        range_check_ptr
    }(
        to_add: felt,
        last_div: felt,
        t1: felt
    ) -> (res: felt):
    let add_res: felt = last_div + to_add
    let mul_res: felt = add_res * 10 ** 7
    let (res, r) = safe_div(mul_res, t1)
    return (res)
end

@external
func std_normal_cdf{
        range_check_ptr
    }(x: felt) -> (res: felt):
    alloc_locals

    let min_return: felt = is_le(x, MIN_CDF_STD_DIST_INPUT - 1)
    if min_return == 1:
        return(0)
    end

    let max_return: felt = is_le(MAX_CDF_STD_DIST_INPUT + 1, x)
    if max_return == 1:
        return(HIGH_PRECISION)
    end

    let abs_x: felt = abs_value(x)
    let abs_x_mul: felt = multiply_decimal_round_precise(2315419, abs_x)
    local t1: felt = 10 ** 7 + abs_x_mul

    let (x_over_2, _) = safe_div(x, 2)
    let exponent: felt = multiply_decimal_round_precise(x, x_over_2)

    let exp_exponent: felt = exp(exponent)

    let d: felt = divide_decimal_round_precise(3989423, exp_exponent)

    # calc prob
    let first_div: felt = _std_normal_cdf_prob_helper(0, 13302740, t1)
    let second_div: felt = _std_normal_cdf_prob_helper(-18212560, first_div, t1)
    let third_div: felt = _std_normal_cdf_prob_helper(17814780, second_div, t1)
    let fourth_div: felt = _std_normal_cdf_prob_helper(-3565638, third_div, t1)
    
    let inter_add: felt = fourth_div + 3193815
    let inter_mul: felt = inter_add * 10 ** 7
    let prob_num: felt = inter_mul * d
    let (local prob, r_prob) = safe_div(prob_num, t1)

    let is_x_negative: felt = is_le(x, -1)
    if is_x_negative == 0:
        let _addition: felt = 10 ** 14 - prob
        let f_prob: felt = divide_decimal_round_precise(_addition, 10 ** 14)
        return(f_prob)
    else:
        let f_prob: felt = divide_decimal_round_precise(prob, 10 ** 14)
        return(f_prob)
    end
end

@external
func d1d2{
        range_check_ptr
    }(
        tAnnualised: felt,
		volatility: felt,
		spot: felt,
		strike: felt,
		rate: felt
    ) -> (
        d1: felt,
        d2: felt
    ):
    alloc_locals

    # make sure every input except rate is unsigned (i.e. +ve)


    let tA_min: felt = is_le(tAnnualised, MIN_T_ANNUALISED - 1)
    if tA_min == 1:
        return d1d2(MIN_T_ANNUALISED, volatility, spot, strike, rate)
    end

    let vol_min: felt = is_le(volatility, MIN_VOLATILITY - 1)
    if vol_min == 1:
        return d1d2(MIN_T_ANNUALISED, volatility, spot, strike, rate)
    end

    # calc v2t
    let v_sq: felt = multiply_decimal_round_precise(volatility, volatility)
    let (v_sq_over_2, _) = safe_div(v_sq, 2)
    let v_plus_rate: felt = v_sq_over_2 + rate
    let (local v2t: felt) = multiply_decimal_round_precise(v_plus_rate, tAnnualised)

    let sqrt_tA: felt = sqrt_precise(tAnnualised)
    let (local vt_sqrt: felt) = multiply_decimal_round_precise(volatility, sqrt_tA)
    let spot_over_strike: felt = divide_decimal_round_precise(spot, strike)
    let log: felt = ln(spot_over_strike)

    # calc d1
    let log_plus_v2: felt = log + v2t
    let (local d1: felt) = divide_decimal_round_precise(log_plus_v2, vt_sqrt)

    # calc d2
    let d2: felt = d1 - vt_sqrt

    return (d1, d2)
end

@external
func delta{
        range_check_ptr
    }(
        tAnnualised: felt,
		volatility: felt,
		spot: felt,
		strike: felt,
		rate: felt
    ) -> (
        call_delta: felt,
        put_delta: felt
    ):
    alloc_locals
    let (local d1, _) = d1d2(tAnnualised, volatility, spot, strike, rate)
    let (local call_delta: felt) = std_normal_cdf(d1)
    let put_delta: felt = call_delta - HIGH_PRECISION
    return (call_delta, put_delta)
end


@external
func gamma{
        range_check_ptr
    }(
        tAnnualised: felt,
		volatility: felt,
		spot: felt,
		strike: felt,
		rate: felt
    ) -> (
        gamma: felt
    ):
    alloc_locals    

    let (local d1, _) = d1d2(tAnnualised, volatility, spot, strike, rate)
    let (local s_n_d1: felt) = std_normal(d1)

     let tA_sqrt: felt = sqrt_precise(tAnnualised)
     let spot_times_ta_sqrt: felt = multiply_decimal_round_precise(spot, tA_sqrt)
     let v_spot_times_ta_sqrt: felt = multiply_decimal_round_precise(volatility, spot_times_ta_sqrt)

    let _gamma: felt = divide_decimal_round_precise(s_n_d1, v_spot_times_ta_sqrt)
    return (_gamma)
end


@external
func vega{
        range_check_ptr
    }(
        tAnnualised: felt,
		volatility: felt,
		spot: felt,
		strike: felt,
		rate: felt
    ) -> (
        vega: felt
    ):
    alloc_locals
    let (local d1, _) = d1d2(tAnnualised, volatility, spot, strike, rate)
    let std_d1: felt = std_normal(d1)
    let (local std_d1_times_spot: felt) = multiply_decimal_round_precise(std_d1, spot)
    
    let tA_sqrt: felt = sqrt_precise(tAnnualised)
    let _vega: felt = multiply_decimal_round_precise(tA_sqrt, std_d1_times_spot)
    return (_vega)
end


@external
func rho{
        range_check_ptr
    }(
        tAnnualised: felt,
		volatility: felt,
		spot: felt,
		strike: felt,
		rate: felt
    ) -> (
        call_rho: felt,
        put_rho: felt
    ):
    alloc_locals

    let (local s_t: felt) = multiply_decimal_round_precise(strike, tAnnualised)
    let r_t: felt = multiply_decimal_round_precise(rate, tAnnualised)
    let exp_rt: felt = exp(-1 * r_t)
    let (local inter: felt) = multiply_decimal_round_precise(s_t, exp_rt)

    # cdfs
    let (_, local d2: felt) = d1d2(tAnnualised, volatility, spot, strike, rate)
    let (local d2_cdf: felt) = std_normal_cdf(d2)
    let (local d2_neg_cdf: felt) = std_normal_cdf(d2 * -1)

    let (local call_rho: felt) = multiply_decimal_round_precise(inter, d2_cdf)
    let put_rho: felt = multiply_decimal_round_precise(inter, d2_neg_cdf)

    return (call_rho, -1 * put_rho)
end


@external 
func theta{
        range_check_ptr
    }(
		tAnnualised: felt,
        volatility: felt,
        spot: felt,
        strike: felt,
        rate: felt
  ) -> (call_theta: felt, put_theta: felt):
    alloc_locals

    let (local d1, local d2) = d1d2(tAnnualised, volatility, spot, strike, rate)
    
    # first half
    let spot_mul_vol: felt = multiply_decimal_round_precise(spot, volatility)
    let n_d1: felt = std_normal(d1)
    let (local first_half_num: felt) = multiply_decimal_round_precise(spot_mul_vol, n_d1)
    let sqrt_t: felt = sqrt_precise(tAnnualised)
    let (local first_half: felt) = divide_decimal_round_precise(first_half_num, 2 * sqrt_t)

    # second half
    let (local r_mul_strike: felt) = multiply_decimal_round_precise(rate, strike)
    let r_mul_tA: felt = multiply_decimal_round_precise(rate, tAnnualised)
    let exp_r_tA: felt = exp(-1 * r_mul_tA)
    let (local r_strike_exp_rtA: felt) = multiply_decimal_round_precise(r_mul_strike, exp_r_tA)
   
    # call second half
    let cdf_d2: felt = std_normal_cdf(d2)
    let call_second_half: felt = multiply_decimal_round_precise(r_strike_exp_rtA, cdf_d2)
    let _call_theta: felt = first_half - call_second_half 
    let (local call_theta, _) = safe_div(_call_theta, 365)

    # put second half
    let cdf_d2_n: felt = std_normal_cdf(-1 * d2)
    let (put_second_half: felt) = multiply_decimal_round_precise(r_strike_exp_rtA, cdf_d2_n)
    let _put_theta: felt = first_half + put_second_half
    let (put_theta, _) = safe_div(_put_theta, 365)

    return (call_theta, put_theta)
end

@external
func option_prices{
        range_check_ptr
    }(
        tAnnualised: felt,
        volatility: felt,
        spot: felt,
        strike: felt,
        rate: felt
    ) -> (call_price: felt, put_price: felt):
    alloc_locals

    # makes sure necessary values are +ve
    # check_input_sanity(
    #     tAnnualised,
	# 	volatility,
	# 	spot,
	# 	strike
    # )

    # d1 d2
    let (local d1, local d2) = d1d2(tAnnualised, volatility, spot, strike, rate)

    # calc strikePv
    let rate_mul_tA: felt = multiply_decimal_round_precise(rate, tAnnualised)
    let exp_rate_mul_tA: felt = exp(-1 * rate_mul_tA)
    let (local strike_pv: felt) = multiply_decimal_round_precise(strike, exp_rate_mul_tA)

    # calc spotNd1
    let s_cdf_d1: felt = std_normal_cdf(d1)
    let (local spotN_d1: felt) = multiply_decimal_round_precise(spot, s_cdf_d1)

    # calc strikeNd2
    let s_cdf_d2: felt = std_normal_cdf(d2)
    let (local strikeN_d2: felt) = multiply_decimal_round_precise(strike_pv, s_cdf_d2)

    let is_nd2_le_nd1: felt  = is_le(strikeN_d2, spotN_d1)
    if is_nd2_le_nd1 == 1:
        let _call: felt = spotN_d1 - strikeN_d2 # replace this with safe add
        let inter_put: felt = _call + strike_pv
        let _is_spot_le_put: felt = is_le(spot, inter_put)
        if _is_spot_le_put == 1:
            let put: felt = inter_put - spot # replace this with safe add
            return (_call, put)
        else:
            return (_call, 0)
        end
    else:
        let _is_spot_le_strike_pv: felt = is_le(spot, strike_pv)
        if _is_spot_le_strike_pv == 1:
            let put: felt = strike_pv - spot # replace this with safe add
            return (0, put)
        else:
            return (0, 0)
        end
    end
end
