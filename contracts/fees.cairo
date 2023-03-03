// Fees of the AMM

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from math64x61 import Math64x61

from constants import FEE_PROPORTION_PERCENT
from types import Math64x61_


// Fees might be in the future dependent on many different variables and on current state.
func get_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value: Math64x61_
) -> (fees: Math64x61_) {
    let fee_proportion = Math64x61.fromFelt(FEE_PROPORTION_PERCENT);
    let hundred = Math64x61.fromFelt(100);
    let fee_proportion = Math64x61.div(fee_proportion, hundred);
    let fees = Math64x61.mul(fee_proportion, value);
    return (fees,);
}
