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