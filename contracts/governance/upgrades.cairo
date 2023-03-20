// Upgrades of the governance itself, proxy_utils, etc
// Leans heavily on proxy_utils.cairo

%lang starknet

from proxy_library import Proxy
from interface_governance_token import IGovernanceToken

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

// Initializer

// Storage_var to store the governance token address
@storage_var
func governance_token_address() -> (addr: felt) {
}


@view
func get_governance_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: felt) {
    let (addr) = governance_token_address.read();
    return (addr,);
}



@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    governance_token_addr: felt,
) {
    // Initialize the proxy and assert it's not yet init'd
    Proxy.initializer();
    // This means we can't change the governance token address once the Proxy is deployed
    // (Unless we use a different storage_var)

    governance_token_address.write(governance_token_addr);

    // Initialize gov token, mint the governance tokens

    let initial_supply_team = Uint256(1000000000000000000, 0); // 10**18
    // TODO add all recipients
    let (governance_address) = get_contract_address();
    IGovernanceToken.initializer(
        contract_address=governance_token_addr,
        name='Carmine development gov token',
        symbol='CARMDEV',
        decimals=18,
        initial_supply=initial_supply_team,
        recipient=TEAM_MULTISIG_ADDR,
        proxy_admin=governance_address
    );

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

@view
func get_contract_version{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    version: felt
) {
    // 0.0.1 first deployed
    // 0.0.2 unsuccessful upgrade due to bug
    // 0.0.3 deploy anew with vote() fixed
    // 0.0.4 only changed the version, no changes to the code, deployed via governance! = 0x4357a4586ec2437f013dd071bd04451ac641191b5666203ff1c82c052d92dce
    // 0.0.5 PROPOSAL_VOTING_TIME_BLOCKS = 50 (from 200), not yet deployed
    let version = '0.0.4';
    return (version = version);
}
