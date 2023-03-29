// Upgrades of the governance itself, proxy_utils, etc
// Leans heavily on proxy_utils.cairo

%lang starknet

from proxy_library import Proxy
from interface_governance_token import IGovernanceToken
from interface_amm import IAMM

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

// Storage_var to store the governance token address
@storage_var
func governance_token_address() -> (addr: felt) {
}

@view
func get_governance_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: felt) {
    let (addr) = governance_token_address.read();
    return (addr,);
}

// Storage_var to store the AMM address
@storage_var
func amm_address() -> (addr: felt) {
}

@view
func get_amm_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: felt) {
    let (addr) = amm_address.read();
    return (addr,);
}

// Initializer

@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    governance_token_addr: felt,
    amm_addr: felt
) {
    // Initialize the proxy and assert it's not yet init'd. Ensures noone can call the initializer again.
    Proxy.initializer();

    // This means we can't change the governance token address once the Proxy is deployed
    // (Unless we use a different storage_var)
    governance_token_address.write(governance_token_addr);
    amm_address.write(amm_addr);

    // Initialize gov token, mint the governance tokens

    let initial_supply_per_teammember = Uint256(1000000000000000000, 0); // 10**18, 1 CARM
    // TODO add all recipients
    let (governance_address) = get_contract_address();
    const recipient_1 = 0x001dd8e12b10592676e109c85d6050bdc1e17adf1be0573a089e081c3c260ed9; // Ondra
    IGovernanceToken.initializer(
        contract_address=governance_token_addr,
        name='Carmine dev gov token v0',
        symbol='CARMDEV0',
        decimals=18,
        initial_supply=initial_supply_per_teammember,
        recipient=recipient_1,
        proxy_admin=governance_address
    );
    IGovernanceToken.mint(contract_address=governance_token_addr, to=0x01159a8E3f50Bf7919EB3684d08e91E28e014013E66AC5e5b3EA752A47426AF4, amount=initial_supply_per_teammember); // Marek
    IGovernanceToken.mint(contract_address=governance_token_addr, to=0x00CcAd7A3e7d1B16Db2aE10d069176f0BfB205DE68c4627D91afF59f0D0F9382, amount=initial_supply_per_teammember); // Andrej
    IGovernanceToken.mint(contract_address=governance_token_addr, to=0x029AF9CF62C9d871453F3b033e514dc790ce578E0e07241d6a5feDF19cEEaF08, amount=initial_supply_per_teammember); // David
    IGovernanceToken.mint(contract_address=governance_token_addr, to=0x04d2FE1Ff7c0181a4F473dCd982402D456385BAE3a0fc38C49C0A99A620d1abe, amount=initial_supply_per_teammember); // Filip

    // TODO initialize AMM fully. This just puts it under governance control, doesn't make it work.
    IAMM.initializer(contract_address=amm_addr, proxy_admin=governance_address);


    // set investor_voting_power, total_investor_distributed_power
    investor_voting_power.write(0x001dd8e12b10592676e109c85d6050bdc1e17adf1be0573a089e081c3c260ed9, 10); // Ondra plays one investor here
    investor_voting_power.write(0x01159a8E3f50Bf7919EB3684d08e91E28e014013E66AC5e5b3EA752A47426AF4, 10); // Marek is another investor
    total_investor_distributed_power.write(20);

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

// @dev 0 = amm, 1 = governance, 2 = CARM token
@external
func apply_passed_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(prop_id: felt) {
    let (status) = get_proposal_status(prop_id=prop_id);
    with_attr error_message("Proposal not passed") {
        assert status = 1;
    }
    let (prop_details) = get_proposal_details(prop_id=prop_id);
    let contract_type = prop_details.to_upgrade;
    with_attr error_message("Invalid contract type for upgrade") {
        assert_nn_le(contract_type, 2);
    }
    if(contract_type == 1){
        Proxy._set_implementation_hash(new_implementation=prop_details.impl_hash);
    }else{if(contract_type == 2){
        let govtoken_addr = governance_token_address.read();
        IGovernanceToken.upgrade(contract_address=govtoken_addr, new_implementation=prop_details.impl_hash);
    }else{if(contract_type == 0){
        let amm_addr = amm_address.read();
        IAMM.upgrade(contract_address=amm_addr, new_implementation=prop_details.impl_hash);
    }}}
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
    // 0.0.6 vote_investor added
    // 0.1 whole team test on testnet
    // 0.2. whole team votes to upgrade to this version
    // 0.2.1 attempt to upgrade to it with test of investor voting, proposal didn't meet quorum (only 1 voter)
    // 0.3 prop 3 really fix investor voting = 0x1205e5c9ecef26004ce6b416bcc6a17ab5839ad39bd9fcb4c183758122feb3e
    let version = '0.3';
    return (version = version);
}
