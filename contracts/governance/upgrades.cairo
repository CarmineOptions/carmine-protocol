// Upgrades of the governance itself, proxy_utils, etc
// Leans heavily on proxy_utils.cairo

%lang starknet

from interface_governance_token import IGovernanceToken
from interface_amm import IAMM
from interface_lptoken import ILPToken

from proxy_library import Proxy
from orchestration import deploy_via_proxy, add_option
from gov_constants import OPTION_CALL, OPTION_PUT, TRADE_SIDE_LONG, TRADE_SIDE_SHORT

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address, deploy
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.alloc import alloc

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
    proxy_class: felt,
    govtoken_class: felt,
    amm_class: felt,
    lpt_class: felt,
    opt_class: felt
) {
    alloc_locals;
    // Initialize the proxy and assert it's not yet init'd. Ensures noone can call the initializer again.
    Proxy.initializer();

    with_attr error_message("unable to compute salt"){
        let salt = proxy_class + govtoken_class;
        let salt = salt + amm_class;
        let salt = salt + lpt_class;
        let salt = salt + opt_class;
    }

    // deploy AMM
    with_attr error_message("Unable to deploy AMM"){
        let (local amm_addr) = deploy_via_proxy(
            proxy_class=proxy_class,
            impl_class=amm_class,
            salt=salt
        );
        amm_address.write(amm_addr);
    }

    // deploy governance token
    with_attr error_message("Unable to deploy govtoken"){
        let (local governance_token_addr) = deploy_via_proxy(
            proxy_class=proxy_class,
            impl_class=govtoken_class,
            salt=salt
        );
        governance_token_address.write(governance_token_addr);
    }


    // Initialize gov token, mint the governance tokens

    let initial_supply_per_teammember = Uint256(1000000000000000000, 0); // 10**18, 1 CARM
    // TODO add all recipients and precise amts
    let (governance_address) = get_contract_address();
    const recipient_1 = 0x001dd8e12b10592676e109c85d6050bdc1e17adf1be0573a089e081c3c260ed9; // Ondra
    IGovernanceToken.initializer(
        contract_address=governance_token_addr,
        name='Carmine dev gov token v1',
        symbol='CARMDEV1',
        decimals=18,
        initial_supply=initial_supply_per_teammember,
        recipient=recipient_1,
        proxy_admin=governance_address
    );
    IGovernanceToken.mint(contract_address=governance_token_addr, to=0x028b14F588C3E68DD92067a9D8604709A002Bfd6d0C2c2e8D92a777967B6d2DF, amount=initial_supply_per_teammember); // Marek
    IGovernanceToken.mint(contract_address=governance_token_addr, to=0x00CcAd7A3e7d1B16Db2aE10d069176f0BfB205DE68c4627D91afF59f0D0F9382, amount=initial_supply_per_teammember); // Andrej
    IGovernanceToken.mint(contract_address=governance_token_addr, to=0x029AF9CF62C9d871453F3b033e514dc790ce578E0e07241d6a5feDF19cEEaF08, amount=initial_supply_per_teammember); // David
    IGovernanceToken.mint(contract_address=governance_token_addr, to=0x04d2FE1Ff7c0181a4F473dCd982402D456385BAE3a0fc38C49C0A99A620d1abe, amount=initial_supply_per_teammember); // Filip

    // set investor_voting_power, total_investor_distributed_power
    investor_voting_power.write(0x001dd8e12b10592676e109c85d6050bdc1e17adf1be0573a089e081c3c260ed9, 10); // Ondra plays one investor here
    investor_voting_power.write(0x028b14F588C3E68DD92067a9D8604709A002Bfd6d0C2c2e8D92a777967B6d2DF, 10); // Marek is another investor
    total_investor_distributed_power.write(20);

    // Initialize AMM
    IAMM.initializer(contract_address=amm_addr, proxy_admin=governance_address);

    // TODO adjust USDC/ETH addr for mainnet
    const USDC_addr = 0x5a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426; // TESTNET, quote token
    const ETH_addr = 0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
    let ZERO = Uint256(0, 0);

    // deploy call pool ETH lptoken
    with_attr error_message("Unable to deploy call pool"){
        let (eth_lpt_addr) = deploy_via_proxy(
            proxy_class=proxy_class,
            impl_class=lpt_class,
            salt=salt
        );
        ILPToken.initializer(
            contract_address=eth_lpt_addr,
            name='Carmine ETH call pool',
            symbol='C-ETH-CALL',
            proxy_admin=governance_address
        );
        // initialize ETH call pool
        const ETH_volatility_adjustment_speed = 34587645138205409280; // 15*2**61 = 15 ETH
        let ETH_max_lpool_balance = Uint256(low=30000000000000000000,high=0); // 30 ETH 
        IAMM.add_lptoken(
            contract_address=amm_addr,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=0, // call pool
            lptoken_address=eth_lpt_addr,
            pooled_token_addr=ETH_addr,
            volatility_adjustment_speed=ETH_volatility_adjustment_speed,
            max_lpool_bal=ETH_max_lpool_balance
        );
    }

    // deploy put pool USDC lptoken
    with_attr error_message("Unable to deploy put pool"){
        let put_salt = salt + 1;
        let (usdc_lpt_addr) = deploy_via_proxy(
            proxy_class=proxy_class,
            impl_class=lpt_class,
            salt=put_salt
        );
        ILPToken.initializer(
            contract_address=usdc_lpt_addr,
            name='Carmine USDC put pool',
            symbol='C-USDC-PUT',
            proxy_admin=governance_address
        );
        // initialize USDC put pool
        const USDC_volatility_adjustment_speed = 57646075230342348800000; // 25000*2**61 = 25k USDC
        let USDC_max_lpool_balance = Uint256(low=50000000000000000000000, high=0); // 50k USDC
        IAMM.add_lptoken(
            contract_address=amm_addr,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=1, // put pool
            lptoken_address=usdc_lpt_addr,
            pooled_token_addr=USDC_addr,
            volatility_adjustment_speed=USDC_volatility_adjustment_speed,
            max_lpool_bal=USDC_max_lpool_balance
        );
    }

    const EXPIRY_07APR23 = 1680825600; // 2023-04-07 00:00:00 UTC
    const EXPIRY_14APR23 = 1681459200; // 2023-04-14 08:00:00 UTC
    const STRIKE_1800 = 4150517416584649113600; // 1800*2**61
    const STRIKE_1900 = 4381101717506018508800; // 1900*2**61
    const VOLATILITY_60 = 138350580552821637120;

    with_attr error_message("Failed to add options"){
        add_option(
            name='ETH-07APR23-1800-LONG-CALL',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_LONG,
            maturity=EXPIRY_07APR23,
            strike_price=STRIKE_1800,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_CALL,
            lptoken_address=eth_lpt_addr,
            initial_volatility=VOLATILITY_60,
        );

        add_option(
            name='ETH-07APR23-1800-SHORT-CALL',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_SHORT,
            maturity=EXPIRY_07APR23,
            strike_price=STRIKE_1800,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_CALL,
            lptoken_address=eth_lpt_addr,
            initial_volatility=VOLATILITY_60,
        );

        add_option(
            name='ETH-07APR23-1800-LONG-PUT',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_LONG,
            maturity=EXPIRY_07APR23,
            strike_price=STRIKE_1800,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_PUT,
            lptoken_address=usdc_lpt_addr,
            initial_volatility=VOLATILITY_60,
        );

        add_option(
            name='ETH-07APR23-1800-SHORT-PUT',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_SHORT,
            maturity=EXPIRY_07APR23,
            strike_price=STRIKE_1800,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_PUT,
            lptoken_address=usdc_lpt_addr,
            initial_volatility=VOLATILITY_60,
        );
    }

    return ();
}

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
    let (applied) = proposal_applied.read(prop_id=prop_id);
    with_attr error_message("Proposal already applied") {
        assert applied = FALSE;
        proposal_applied.write(prop_id=prop_id, value=TRUE);
    }
    let (prop_details) = get_proposal_details(prop_id=prop_id);
    let contract_type = prop_details.to_upgrade;
    if(contract_type == 0){
        let (amm_addr) = amm_address.read();
        IAMM.upgrade(contract_address=amm_addr, new_implementation=prop_details.impl_hash);
        return ();
    }
    if(contract_type == 1){
        Proxy._set_implementation_hash(new_implementation=prop_details.impl_hash);
        return ();
    }
    if(contract_type == 2){
        let (govtoken_addr) = governance_token_address.read();
        IGovernanceToken.upgrade(contract_address=govtoken_addr, new_implementation=prop_details.impl_hash);
        return ();
    }
    with_attr error_message("Invalid contract type for upgrade") {
        assert 1 = 0;
    }
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
    // 0.4 can upgrade stuff other than governance, deploy and init whole AMM
    let version = '0.4';
    return (version = version);
}
