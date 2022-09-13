%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_equal

from contracts.fees import get_fees

from math64x61 import Math64x61

@external
func test_get_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (option_size) = Math64x61.fromFelt(100);
    let (fees) = get_fees(1672527600);
    let (target) = Math64x61.fromFelt(3);
    assert_not_equal(fees, target);
    return ();
}
