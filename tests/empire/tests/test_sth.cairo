%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.main import convert_price, iter_div_64x61

from starkware.cairo.common.pow import pow


from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_le, unsigned_div_rem
from starkware.cairo.common.bool import TRUE

from contracts.Math64x61 import (
    Math64x61_fromFelt,
    Math64x61_div,
    Math64x61_fromUint256,
    Math64x61_toFelt,
    Math64x61_INT_PART,
    Math64x61_add,
    Math64x61_sqrt
)

@external
func test_convert_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (option_size) = Math64x61_fromFelt(100)
    let (fees) = convert_price(1480230000000000065536, 19)
    let target = 341317799752838634967 # for decimala = 19
    let (x) = Math64x61_fromFelt(10)
    # let (fees) = Math64x61_div(option_size, x)

    assert fees = target
    return ()
end


@external
func test_iter_div_64x61{range_check_ptr} () -> (res: felt):
    # both x and y are Math64x61
    # this is needed because of weird error in overflow
    alloc_locals
    let x_ = 65536
    let (y_) = pow(10, 19)
    let (x) = Math64x61_fromFelt(x_)
    let (y) = Math64x61_fromFelt(y_) # 10**19*2**61
    # let y = 7291715840636310552495090012

    let pow_10_to_30 = 10**30
    let (is_convertable) = is_le(y, pow_10_to_30)

    assert 0 = is_convertable
    
    if is_convertable == 1:
        let (res_a) = Math64x61_div(x, y)
        return (res_a)
    end

    let (div_a) = Math64x61_sqrt(y)
    let (div_b) = Math64x61_div(y, div_a)

    assert 7291715840636310552495090012 = div_a
    assert 7291715831147479162736768891 = div_b

    let (partial_res) = iter_div_64x61(x, div_a)
    assert 47786988871008 = partial_res
    let (res) = iter_div_64x61(partial_res, div_b)
    assert 15111 = res

    assert 5=3

    return (res)
end
