# Contract that calculates Black-Scholes with Choudhury's approximation to std normal CDF
# https://www.hrpub.org/download/20140305/MS7-13401470.pdf.

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import sign

# Third party imports. Was copy pasted to this repo.
from contracts.Math64x61 import (
    Math64x61_fromFelt,
    Math64x61_toFelt,
    Math64x61_exp,
    Math64x61_sqrt,
    Math64x61_mul,
    Math64x61_div,
    Math64x61_add
)


const INPUT_UNIT = 10**16


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
    let (input_unadjusted) = Math64x61_fromFelt(x)
    let (input) = Math64x61_div(input_unadjusted, base)

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
    #let (MINUS_ONE) = Math64x61_fromFelt(-1)
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

# Calculates approximate value for Black Scholes
# TBD
@view
func black_scholes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(x: felt) -> (
    res : felt
):
    let res = 4 * 4
    return (res)
end
