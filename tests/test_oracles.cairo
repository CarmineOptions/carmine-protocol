%lang starknet

from starkware.cairo.common.pow import pow
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_le, unsigned_div_rem
from starkware.cairo.common.bool import TRUE, FALSE

from contracts.Math64x61 import (
    Math64x61_fromFelt,
    Math64x61_div,
    Math64x61_fromUint256,
    Math64x61_toFelt,
    Math64x61_INT_PART,
    Math64x61_add,
    Math64x61_sqrt,
)
from contracts.oracles import convert_price, iter_div_64x61, empiric_median_price, IEmpiricOracle

from contracts._cfg import EMPIRIC_ORACLE_ADDRESS, EMPIRIC_ETH_USD_KEY, EMPIRIC_AGGREGATION_MODE

@external
func test_convert_price{range_check_ptr}():
    # Test price is 1480.23 * 10**18
    let test_price = 1480230000000000000000
    let (converted_price) = convert_price(test_price, 18)

    # Target price is approx. = test_price / 10**18 * 2**61
    let target_price = 3413177997528386198568

    # This was checked manually
    assert converted_price = target_price
    return ()
end

@external
func test_iter_div_64x61{range_check_ptr}() -> (res : felt):
    # both x and y are Math64x61
    # this is needed because of weird error in overflow
    alloc_locals
    let x_ = 65536
    let (y_) = pow(10, 19)
    let (x) = Math64x61_fromFelt(x_)
    let (y) = Math64x61_fromFelt(y_)  # 10**19*2**61
    # let y = 7291715840636310552495090012

    let pow_10_to_30 = 10 ** 30
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

    return (res)
end

@external
func test_empiric_median_price{range_check_ptr, syscall_ptr : felt*}():
    %{
        # Not all returned values are used atm, hence the 0s
        stop_mock = mock_call(
            ids.EMPIRIC_ORACLE_ADDRESS, "get_value", [1480230000000000000000, 18, 0, 0]
        )
    %}

    let (res) = empiric_median_price(EMPIRIC_ETH_USD_KEY)

    %{ stop_mock() %}

    # Same test values as in test_convert_price
    assert res = 3413177997528386198568
    return ()
end
