#https://github.com/gaetbout/starknet-array-manipulation/blob/main/contracts/utils.cairo
%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le, is_not_zero
from starkware.cairo.common.bool import TRUE
# Checking

func assert_index_in_array_length{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(arr_len : felt, index : felt):
    let (res) = is_le(index, arr_len)
    with_attr error_message("Index out of range"):
        assert res = TRUE
    end
    return ()
end

func assert_from_smaller_then_to{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    from_index : felt, to_index : felt
):
    let (res) = is_le(from_index + 1, to_index)
    with_attr error_message("From should be strictly smaller then to"):
        assert res = TRUE
    end
    return ()
end

func assert_check_array_not_empty{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(arr_len : felt):
    let (res) = is_not_zero(arr_len)
    with_attr error_message("Empty array"):
        assert res = TRUE
    end
    return ()
end