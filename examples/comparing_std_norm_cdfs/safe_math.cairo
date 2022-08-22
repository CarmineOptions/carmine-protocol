# Declare this file as a StarkNet contract and set the required
# builtins.
# %lang starknet
# %builtins pedersen range_check

from starkware.cairo.common.math_cmp import (
    is_le, is_nn
)
from starkware.cairo.common.math import (
    abs_value, signed_div_rem, assert_250_bit
)

const RC_BOUND = 2 ** 128
const DIV_BOUND = 170141183460469231731687303715884105728 # (2 ** 128) // 2
const HIGH_PRECISION = 10 ** 27
const HIGH_PRECISION_DIV_10 = 10 ** 26
const HIGH_PRECISION_TIMES_10 = 10 ** 28
const PRECISION = 10 ** 18

func check_rc_bound{
        range_check_ptr
    }(value: felt):
    abs_value(value)
    return()
end

# Assumes that all +
func safe_add{
        range_check_ptr
    }(x: felt, y: felt) -> (z: felt):
    let z: felt = x + y
    # assert_250_bit(z)
    return (z)
end

func safe_mul{
        range_check_ptr
    }(x: felt, y: felt) -> (z: felt):
    let z: felt = x * y
    return (z)
end

func safe_div{
        range_check_ptr
    }(x: felt, y:felt) -> (q: felt, r: felt):
    # we cannot pass -ve div to signed_div_rem
    let y_nn: felt = is_nn(y)
    if y_nn == 0:
        # switch signs of x & y (i.e. multiple num & denom by -1)
        let (q, r) = signed_div_rem(x * -1, y * -1, DIV_BOUND) 
        return (q, -1*r)
    else:
        let (q, r) = signed_div_rem(x, y, DIV_BOUND) 
        return (q, r)
    end
end

func multiply_decimal_round_precise{
        range_check_ptr
    }(x: felt, y:felt) -> (z: felt):
    alloc_locals

    let z_mul: felt = safe_mul(x, y)
    let (z_mul_times_10, _) = signed_div_rem(z_mul, HIGH_PRECISION_DIV_10, DIV_BOUND)

    let (local z_div, z_r) = signed_div_rem(z_mul_times_10, 10, DIV_BOUND)

    let no_change: felt = is_le(z_r, 4)
    if no_change == 1:
        return (z_div)
    else:
        return (z_div + 1)
    end 
end

func divide_decimal_round_precise{
        range_check_ptr
    }(x: felt, y:felt) -> (z: felt):
    alloc_locals

    let num_times_10: felt = x * HIGH_PRECISION_TIMES_10
    let (x_times_10, _) = safe_div(num_times_10, y)
    let (local x_mul, x_r) = signed_div_rem(x_times_10, 10, DIV_BOUND)
    let no_change: felt = is_le(x_r, 4)
    if no_change == 1:
        return(x_mul)
    else:
        return(x_mul + 1)
    end
end