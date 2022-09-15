// Fees of the AMM

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from math64x61 import Math64x61

from constants import FEE_PROPORTION_PERCENT

// Fees might be in the future dependent on many different variables and on current state.
func get_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_size: felt
) -> (fees: felt) {
    let three = Math64x61.fromFelt(3);
    let hundred = Math64x61.fromFelt(100);
    let fee_proportion = Math64x61.div(three, hundred);
    let fees = Math64x61.mul(fee_proportion, option_size);
    return (fees,);
}
