# Wrapper for non viewed functions in contracts/fees.cairo
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.fees import get_fees


# wrapper for contracts.fees.get_fees for purpose of unit testing
@view
func testable_get_fees{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_size : felt
) -> (fees : felt):
    let (fees) = get_fees(option_size)
    return (fees=fees)
end
