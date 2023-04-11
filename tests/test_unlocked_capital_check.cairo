%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_mul,
    uint256_add,
    uint256_sub,
    uint256_unsigned_div_rem,
    uint256_le,
    uint256_eq,
    uint256_signed_le,
    assert_uint256_lt,
    assert_uint256_le,
    uint256_signed_nn,
)


@external
func test_unlocked_capital_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let new_balance = Uint256(10029961000000000000, 0);
    let new_locked_capital = Uint256(10029961000000000001, 0); // new_balance + 1
    // Check that there is enough capital to be locked.
    with_attr error_message("Not enough unlocked capital in pool") {
        assert_uint256_le(new_locked_capital, new_balance);
        //let (assert_res) = uint256_sub(new_balance, new_locked_capital);
        //assert_uint256_le(Uint256(0, 0), assert_res);
    }

    // MUST FAIL

    return ();
}
