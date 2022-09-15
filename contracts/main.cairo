// Internals of the AMM

%lang starknet

from contracts.initialize_amm import init_pool, add_fake_tokens
from lib.cairo_contracts.src.openzeppelin.upgrades.library import Proxy

// Initializer

@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    proxy_admin: felt
) {
    Proxy.initializer(proxy_admin);
    return ();
}

// Upgrades

@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_implementation: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(new_implementation);
    return ();
}

// Admin related functions

@view
func getAdmin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    let (address) = Proxy.get_admin();
    return (address,);
}

@external
func setAdmin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) {
    Proxy.assert_only_admin();
    Proxy._set_admin(address);
    return ();
}
