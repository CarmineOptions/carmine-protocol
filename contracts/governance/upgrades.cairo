// Upgrades of the governance itself, proxy_utils, etc
// Leans heavily on proxy_utils.cairo

%lang starknet

from proxy_library import Proxy
from starkware.cairo.common.cairo_builtins import HashBuiltin

// Initializer

@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) {
    Proxy.initializer();
    return ();
}

// // Upgrades

// @external
// func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//     new_implementation: felt
// ) {
//     Proxy.assert_only_admin();
//     Proxy._set_implementation_hash(new_implementation);
//     return ();
// }

// Other utils

@view
func getImplementationHash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    implementation_hash: felt
) {
    let (implementation_hash) = Proxy.get_implementation_hash();
    return (implementation_hash = implementation_hash);
}

@external
func apply_passed_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(prop_id: felt) {
    let (status) = get_proposal_status(prop_id=prop_id);
    with_attr error_message("Proposal not passed") {
        assert status = 1;
    }
    let (prop_details) = get_proposal_details(prop_id=prop_id);
    with_attr error_message("Invalid contract type for upgrade") {
        assert prop_details.to_upgrade = 1;
    }

    Proxy._set_implementation_hash(new_implementation=prop_details.impl_hash);
    return ();
}