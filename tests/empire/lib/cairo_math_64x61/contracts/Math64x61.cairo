%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math_cmp import is_le, is_not_zero
from starkware.cairo.common.pow import pow
from starkware.cairo.common.math import (
    assert_le,
    assert_lt,
    sqrt,
    sign,
    abs_value,
    signed_div_rem,
    unsigned_div_rem,
    assert_not_zero
)

const Math64x61_INT_PART = 2 ** 64
const Math64x61_FRACT_PART = 2 ** 61
const Math64x61_BOUND = 2 ** 125
const Math64x61_ONE = 1 * Math64x61_FRACT_PART
const Math64x61_E = 6267931151224907085

func Math64x61_assert64x61 {range_check_ptr} (x: felt):
    assert_le(x, Math64x61_BOUND)
    assert_le(-Math64x61_BOUND, x)
    return ()
end

# Converts a fixed point value to a felt, truncating the fractional component
func Math64x61_toFelt {range_check_ptr} (x: felt) -> (res: felt):
    let (res, _) = signed_div_rem(x, Math64x61_FRACT_PART, Math64x61_BOUND)
    return (res)
end

# Converts a felt to a fixed point value ensuring it will not overflow
func Math64x61_fromFelt {range_check_ptr} (x: felt) -> (res: felt):
    assert_le(x, Math64x61_INT_PART)
    assert_le(-Math64x61_INT_PART, x)
    return (x * Math64x61_FRACT_PART)
end

# Converts a fixed point 64.61 value to a uint256 value
func Math64x61_toUint256 (x: felt) -> (res: Uint256):
    let res = Uint256(low = x, high = 0)
    return (res)
end

# Converts a uint256 value into a fixed point 64.61 value ensuring it will not overflow
func Math64x61_fromUint256 {range_check_ptr} (x: Uint256) -> (res: felt):
    assert x.high = 0
    let (res) = Math64x61_fromFelt(x.low)
    return (res)
end

# Calculates the floor of a 64.61 value
func Math64x61_floor {range_check_ptr} (x: felt) -> (res: felt):
    let (int_val, mod_val) = signed_div_rem(x, Math64x61_ONE, Math64x61_BOUND)
    let res = x - mod_val
    Math64x61_assert64x61(res)
    return (res)
end

# Calculates the ceiling of a 64.61 value
func Math64x61_ceil {range_check_ptr} (x: felt) -> (res: felt):
    let (int_val, mod_val) = signed_div_rem(x, Math64x61_ONE, Math64x61_BOUND)
    let res = (int_val + 1) * Math64x61_ONE
    Math64x61_assert64x61(res)
    return (res)
end

# Returns the minimum of two values
func Math64x61_min {range_check_ptr} (x: felt, y: felt) -> (res: felt):
    let (x_le) = is_le(x, y)

    if x_le == 1:
        return (x)
    else:
        return (y)
    end
end

# Returns the maximum of two values
func Math64x61_max {range_check_ptr} (x: felt, y: felt) -> (res: felt):
    let (x_le) = is_le(x, y)

    if x_le == 1:
        return (y)
    else:
        return (x)
    end
end

# Convenience addition method to assert no overflow before returning
func Math64x61_add {range_check_ptr} (x: felt, y: felt) -> (res: felt):
    let res = x + y
    Math64x61_assert64x61(res)
    return (res)
end

# Convenience subtraction method to assert no overflow before returning
func Math64x61_sub {range_check_ptr} (x: felt, y: felt) -> (res: felt):
    let res = x - y
    Math64x61_assert64x61(res)
    return (res)
end

# Multiples two fixed point values and checks for overflow before returning
func Math64x61_mul {range_check_ptr} (x: felt, y: felt) -> (res: felt):
    tempvar product = x * y
    let (res, _) = signed_div_rem(product, Math64x61_FRACT_PART, Math64x61_BOUND)
    Math64x61_assert64x61(res)
    return (res)
end

# Divides two fixed point values and checks for overflow before returning
# Both values may be signed (i.e. also allows for division by negative b)
func Math64x61_div {range_check_ptr} (x: felt, y: felt) -> (res: felt):
    alloc_locals
    let (div) = abs_value(y)
    let (div_sign) = sign(y)
    tempvar product = x * Math64x61_FRACT_PART
    let (res_u, _) = signed_div_rem(product, div, Math64x61_BOUND)
    Math64x61_assert64x61(res_u)
    return (res = res_u * div_sign)
end

# Calclates the value of x^y and checks for overflow before returning
# x is a 64x61 fixed point value
# y is a standard felt (int)
func Math64x61__pow_int {range_check_ptr} (x: felt, y: felt) -> (res: felt):
    alloc_locals
    let (exp_sign) = sign(y)
    let (exp_val) = abs_value(y)

    if exp_sign == 0:
        return (Math64x61_ONE)
    end

    if exp_sign == -1:
        let (num) = Math64x61__pow_int(x, exp_val)
        return Math64x61_div(Math64x61_ONE, num)
    end

    let (half_exp, rem) = unsigned_div_rem(exp_val, 2)
    let (half_pow) = Math64x61__pow_int(x, half_exp)
    let (res_p) = Math64x61_mul(half_pow, half_pow)

    if rem == 0:
        Math64x61_assert64x61(res_p)
        return (res_p)
    else:
        let (res) = Math64x61_mul(res_p, x)
        Math64x61_assert64x61(res)
        return (res)
    end
end

# Calclates the value of x^y and checks for overflow before returning
# x is a 64x61 fixed point value
# y is a 64x61 fixed point value
func Math64x61_pow {range_check_ptr} (x: felt, y: felt) -> (res: felt):
    alloc_locals
    let (y_int, y_frac) = signed_div_rem(y, Math64x61_ONE, Math64x61_BOUND)

    # use the more performant integer pow when y is an int
    if y_frac == 0:
        return Math64x61__pow_int(x, y_int)
    end

    # x^y = exp(y*ln(x)) for x > 0 (will error for x < 0
    let (ln_x) = Math64x61_ln(x)
    let (y_ln_x) = Math64x61_mul(y,ln_x)
    let (res) = Math64x61_exp(y_ln_x)
    return (res)
    # Math64x61_assert64x61(res)
    # return (res)
end

# Calculates the square root of a fixed point value
# x must be positive
func Math64x61_sqrt {range_check_ptr} (x: felt) -> (res: felt):
    alloc_locals
    let (root) = sqrt(x)
    let (scale_root) = sqrt(Math64x61_FRACT_PART)
    let (res, _) = signed_div_rem(root * Math64x61_FRACT_PART, scale_root, Math64x61_BOUND)
    Math64x61_assert64x61(res)
    return (res)
end

# Calculates the most significant bit where x is a fixed point value
# TODO: use binary search to improve performance
func Math64x61__msb {range_check_ptr} (x: felt) -> (res: felt):
    alloc_locals

    let (cmp) = is_le(x, Math64x61_FRACT_PART)

    if cmp == 1:
        return (0)
    end

    let (div, _) = unsigned_div_rem(x, 2)
    let (rest) = Math64x61__msb(div)
    local res = 1 + rest
    Math64x61_assert64x61(res)
    return (res)
end

# Calculates the binary exponent of x: 2^x
func Math64x61_exp2 {range_check_ptr} (x: felt) -> (res: felt):
    alloc_locals

    let (exp_sign) = sign(x)

    if exp_sign == 0:
        return (Math64x61_ONE)
    end

    let (exp_value) = abs_value(x)
    let (int_part, frac_part) = unsigned_div_rem(exp_value, Math64x61_FRACT_PART)
    let (int_res) = Math64x61__pow_int(2 * Math64x61_ONE, int_part)

    # 1.069e-7 maximum error
    const a1 = 2305842762765193127
    const a2 = 1598306039479152907
    const a3 = 553724477747739017
    const a4 = 128818789015678071
    const a5 = 20620759886412153
    const a6 = 4372943086487302

    let (r6) = Math64x61_mul(a6, frac_part)
    let (r5) = Math64x61_mul(r6 + a5, frac_part)
    let (r4) = Math64x61_mul(r5 + a4, frac_part)
    let (r3) = Math64x61_mul(r4 + a3, frac_part)
    let (r2) = Math64x61_mul(r3 + a2, frac_part)
    tempvar frac_res = r2 + a1

    let (res_u) = Math64x61_mul(int_res, frac_res)
    
    if exp_sign == -1:
        let (res_i) = Math64x61_div(Math64x61_ONE, res_u)
        Math64x61_assert64x61(res_i)
        return (res_i)
    else:
        Math64x61_assert64x61(res_u)
        return (res_u)
    end
end

# Calculates the natural exponent of x: e^x
func Math64x61_exp {range_check_ptr} (x: felt) -> (res: felt):
    const mod = 3326628274461080623
    let (bin_exp) = Math64x61_mul(x, mod)
    let (res) = Math64x61_exp2(bin_exp)
    return (res)
end

# Calculates the binary logarithm of x: log2(x)
# x must be greather than zero
func Math64x61_log2 {range_check_ptr} (x: felt) -> (res: felt):
    alloc_locals

    if x == Math64x61_ONE:
        return (0)
    end

    let (is_frac) = is_le(x, Math64x61_FRACT_PART - 1)

    # Compute negative inverse binary log if 0 < x < 1
    if is_frac == 1:
        let (div) = Math64x61_div(Math64x61_ONE, x)
        let (res_i) = Math64x61_log2(div)
        return (-res_i)
    end

    let (x_over_two, _) = unsigned_div_rem(x, 2)
    let (b) = Math64x61__msb(x_over_two)
    let (divisor) = pow(2, b)
    let (norm, _) = unsigned_div_rem(x, divisor)

    # 4.233e-8 maximum error
    const a1 = -7898418853509069178
    const a2 = 18803698872658890801
    const a3 = -23074885139408336243
    const a4 = 21412023763986120774
    const a5 = -13866034373723777071
    const a6 = 6084599848616517800
    const a7 = -1725595270316167421
    const a8 = 285568853383421422
    const a9 = -20957604075893688

    let (r9) = Math64x61_mul(a9, norm)
    let (r8) = Math64x61_mul(r9 + a8, norm)
    let (r7) = Math64x61_mul(r8 + a7, norm)
    let (r6) = Math64x61_mul(r7 + a6, norm)
    let (r5) = Math64x61_mul(r6 + a5, norm)
    let (r4) = Math64x61_mul(r5 + a4, norm)
    let (r3) = Math64x61_mul(r4 + a3, norm)
    let (r2) = Math64x61_mul(r3 + a2, norm)
    local norm_res = r2 + a1

    let (int_part) = Math64x61_fromFelt(b)
    local res = int_part + norm_res
    Math64x61_assert64x61(res)
    return (res)
end

# Calculates the natural logarithm of x: ln(x)
# x must be greater than zero
func Math64x61_ln {range_check_ptr} (x: felt) -> (res: felt):
    const ln_2 = 1598288580650331957
    let (log2_x) = Math64x61_log2(x)
    let (product) = Math64x61_mul(log2_x, ln_2)
    return (product)
end

# Calculates the base 10 log of x: log10(x)
# x must be greater than zero
func Math64x61_log10 {range_check_ptr} (x: felt) -> (res: felt):
    const log10_2 = 694127911065419642
    let (log10_x) = Math64x61_log2(x)
    let (product) = Math64x61_mul(log10_x, log10_2)
    return (product)
end
