%lang starknet

from starkware.cairo.common.pow import pow
from starkware.cairo.common.math_cmp import is_le

from math64x61 import Math64x61
from lib.math_64x61_extended import Math64x61_div_imprecise

from contracts.oracles import convert_price, empiric_median_price
from contracts.constants import EMPIRIC_ORACLE_ADDRESS, EMPIRIC_ETH_USD_KEY, EMPIRIC_AGGREGATION_MODE


@external
func test_convert_price{range_check_ptr}() {
    // Test price is 1480.23 * 10**18
    let test_price = 1480230000000000000000;
    let (converted_price) = convert_price(test_price, 18);

    // Target price is approx. = test_price / 10**18 * 2**61
    let target_price = 3413177997528386198568;

    // This was checked manually
    assert converted_price = target_price;
    return ();
}

@external
func test_Math64x61_div_imprecise{range_check_ptr}() {
    // both x and y are Math64x61
    // this is needed because of weird error in overflow
    alloc_locals;
    let decimals = 18;
    let (pow10xM) = pow(10, decimals);
    let pow10xM_to_64x61 = Math64x61.fromFelt(pow10xM);

    // test ETH price 1480.23 * 10**18
    let eth_test = 1480230000000000000000;
    let eth_res = Math64x61_div_imprecise(eth_test, pow10xM_to_64x61);
    assert eth_res = 1480;

    // test BTC price 21567.86 * 10**18
    let btc_test = 21567860000000000000000;
    let btc_res = Math64x61_div_imprecise(btc_test, pow10xM_to_64x61);
    assert btc_res = 21567;

    // test some random coin worth 0.58 dollars
    let rand_test = 580000000000000000;
    let rand_res = Math64x61_div_imprecise(rand_test, pow10xM_to_64x61);
    assert rand_res = 0;  // FIXME: this should not be zero

    return ();
}

@external
func test_empiric_median_price{range_check_ptr, syscall_ptr: felt*}() {
    tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
    %{
        # Not all returned values are used atm, hence the 0s
        stop_mock = mock_call(
            ids.tmp_address, "get_spot_median", [1480230000000000000000, 18, 0, 0]
        )
    %}

    let (res) = empiric_median_price(EMPIRIC_ETH_USD_KEY);

    %{ stop_mock() %}

    // Same test values as in test_convert_price
    assert res = 3413177997528386198568;
    return ();
}
