#https://github.com/gaetbout/starknet-array-manipulation/blob/main/contracts/array_manipulation.cairo

%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from contracts.array_utils import (
    assert_index_in_array_length,
    assert_check_array_not_empty,
    assert_from_smaller_then_to,
)

func get_new_array{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    arr_len : felt, arr : felt*
):
    alloc_locals
    let (local arr : felt*) = alloc()
    return (0, arr)
end

# Adding

@view
func add_first{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*, item : felt
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    let (new_arr_len, new_arr) = get_new_array()
    assert [new_arr] = item
    memcpy(new_arr + 1, arr, arr_len)
    return (arr_len + 1, new_arr)
end

@view
func add_last{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*, item : felt
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    # We can't just assert at arr_len with the item
    let (new_arr_len, new_arr) = get_new_array()
    memcpy(new_arr, arr, arr_len)
    assert new_arr[arr_len] = item
    return (arr_len + 1, new_arr)
end

@view
func add_at{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*, index : felt, item : felt
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    assert_index_in_array_length(arr_len, index)
    let (new_arr_len, new_arr) = get_new_array()
    memcpy(new_arr, arr, index)
    assert new_arr[index] = item
    memcpy(new_arr + index + 1, arr + index, arr_len - index)
    return (arr_len + 1, new_arr)
end

# Removing

@view
func remove_first{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    assert_check_array_not_empty(arr_len)
    let (new_arr_len, new_arr) = get_new_array()
    memcpy(new_arr, arr + 1, arr_len - 1)
    return (arr_len - 1, new_arr)
end

@view
func remove_last{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    assert_check_array_not_empty(arr_len)
    let (new_arr_len, new_arr) = get_new_array()
    memcpy(new_arr, arr, arr_len - 1)
    return (arr_len - 1, new_arr)
end

@view
func remove_at{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*, index : felt
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    assert_check_array_not_empty(arr_len)
    assert_index_in_array_length(arr_len, index + 1)
    let (new_arr_len, new_arr) = get_new_array()
    memcpy(new_arr, arr, index)
    memcpy(new_arr + index, arr + index + 1, arr_len - index - 1)
    return (arr_len - 1, new_arr)
end

@view
func remove_first_occurence_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*, item : felt
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    assert_check_array_not_empty(arr_len)
    return remove_first_occurence_of_recursive(arr_len, arr, item, 0)
end

func remove_first_occurence_of_recursive{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(arr_len : felt, arr : felt*, item : felt, current_index : felt) -> (arr_len : felt, arr : felt*):
    if arr_len == current_index:
        return (arr_len, arr)
    end
    if arr[current_index] == item:
        return remove_at(arr_len, arr, current_index)
    end
    return remove_first_occurence_of_recursive(arr_len, arr, item, current_index + 1)
end

@view
func remove_last_occurence_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*, item : felt
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    assert_check_array_not_empty(arr_len)
    return remove_last_occurence_of_recursive(arr_len, arr, item, arr_len - 1)
end

func remove_last_occurence_of_recursive{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(arr_len : felt, arr : felt*, item : felt, current_index : felt) -> (arr_len : felt, arr : felt*):
    if arr[current_index] == item:
        return remove_at(arr_len, arr, current_index)
    end
    if current_index == 0:
        return (arr_len, arr)
    end
    return remove_last_occurence_of_recursive(arr_len, arr, item, current_index - 1)
end

@view
func remove_all_occurences_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*, item : felt
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    assert_check_array_not_empty(arr_len)
    let (new_arr_len, new_arr) = get_new_array()
    return remove_all_occurences_of_recursive(arr_len, arr, new_arr_len, new_arr, item)
end

func remove_all_occurences_of_recursive{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(old_arr_len : felt, old_arr : felt*, new_arr_len : felt, new_arr : felt*, item : felt) -> (
    arr_len : felt, arr : felt*
):
    if old_arr_len == 0:
        return (new_arr_len, new_arr)
    end
    if [old_arr] == item:
        return remove_all_occurences_of_recursive(
            old_arr_len - 1, &old_arr[1], new_arr_len, new_arr, item
        )
    end
    assert new_arr[new_arr_len] = [old_arr]
    return remove_all_occurences_of_recursive(
        old_arr_len - 1, &old_arr[1], new_arr_len + 1, new_arr, item
    )
end

# Reverse

@view
func reverse{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*
) -> (arr_len : felt, arr : felt*):
    let (new_arr_len, new_arr) = get_new_array()
    return reverse_recursive(arr_len, arr, new_arr_len, new_arr)
end

func reverse_recursive{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    old_arr_len : felt, old_arr : felt*, new_arr_len : felt, new_arr : felt*
) -> (arr_len : felt, arr : felt*):
    if old_arr_len == 0:
        return (new_arr_len, new_arr)
    end
    assert new_arr[old_arr_len - 1] = [old_arr]
    return reverse_recursive(old_arr_len - 1, &old_arr[1], new_arr_len + 1, new_arr)
end


# Join

@view
func join{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr1_len : felt, arr1 : felt*, arr2_len : felt, arr2 : felt*
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    let (new_arr_len, new_arr) = get_new_array()
    memcpy(new_arr, arr1, arr1_len)
    memcpy(new_arr + arr1_len, arr2, arr2_len)
    return (arr1_len + arr2_len, new_arr)
end

@view
func copy_from_to{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*, from_index : felt, to_index : felt
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    assert_index_in_array_length(arr_len, from_index)
    assert_index_in_array_length(arr_len, to_index)
    assert_from_smaller_then_to(from_index, to_index)
    let (new_arr_len, new_arr) = get_new_array()
    memcpy(new_arr, arr + from_index, to_index - from_index)
    return (to_index - from_index, new_arr)
end

# Replace

@view
func replace{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*, old_item : felt, new_item : felt
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    let (new_arr_len, new_arr) = get_new_array()
    return replace_recursive(arr_len, arr, new_arr_len, new_arr, old_item, new_item)
end

func replace_recursive{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    old_arr_len : felt,
    old_arr : felt*,
    new_arr_len : felt,
    new_arr : felt*,
    old_item : felt,
    new_item : felt,
) -> (sorted_arr_len : felt, sorted_arr : felt*):
    if old_arr_len == 0:
        return (new_arr_len, new_arr)
    end
    let current_item = [old_arr]
    if current_item == old_item:
        assert new_arr[new_arr_len] = new_item
    else:
        assert new_arr[new_arr_len] = current_item
    end
    return replace_recursive(
        old_arr_len - 1, &old_arr[1], new_arr_len + 1, new_arr, old_item, new_item
    )
end