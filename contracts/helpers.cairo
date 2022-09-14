// Helper functions

%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le

func max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value_a: felt, value_b: felt
) -> (max_value: felt) {
    let a_smaller_b = is_le(value_a, value_b);

    if (a_smaller_b == TRUE) {
        return (value_b,);
    }
    return (value_a,);
}

func min{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value_a: felt, value_b: felt
) -> (max_value: felt) {
    let a_smaller_b = is_le(value_a, value_b);

    if (a_smaller_b == TRUE) {
        return (value_a,);
    }
    return (value_b,);
}
