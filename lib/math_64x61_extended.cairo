%lang starknet

from starkware.cairo.common.pow import pow
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.bool import TRUE, FALSE

from contracts.Math64x61 import Math64x61_div, Math64x61_sqrt

# Function for iterative division
func Math64x61_div_imprecise{range_check_ptr}(x : felt, y : felt) -> (res : felt):
    # both x and y are Math64x61
    # this is needed because of weird error in overflow
    # this may introduce imprecisions
    alloc_locals

    # check whether the number is small enough to
    # be divisible without causing error
    let (pow_10_to_30) = pow(10, 30)
    let (is_convertable) = is_le(y, pow_10_to_30)
    if is_convertable == TRUE:
        let (res_a) = Math64x61_div(x, y)
        return (res_a)
    end

    # div a and b calculated differently due to imprecision
    let (div_a) = Math64x61_sqrt(y)
    let (div_b) = Math64x61_div(y, div_a)

    # x / y = x / ( sqrt(y) * sqrt(y) )
    let (partial_res) = Math64x61_div_imprecise(x, div_a)
    let (res) = Math64x61_div_imprecise(partial_res, div_b)

    return (res)
end
