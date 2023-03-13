%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import assert_nn_le

// @notice Converts the value from Int (felt) to Uint256
// @dev Fails if value too big, otherwise returns { low: value, high: 0 }
// @param x: Value to be converted
// @return Value as Uint256
func intToUint256{range_check_ptr}(
    x: felt
) -> Uint256 {
    // We can use split_felt if we want to do it now!
    with_attr error_message("Unable to work with x this big until Cairo 1.0 comes along") {
        assert_nn_le(x, 2**127-1);
        let res = Uint256(x, 0);
    }
    return res;
}
