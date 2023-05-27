// Upgrades of the governance itself, proxy_utils, etc
// Leans heavily on proxy_utils.cairo

%lang starknet

from interface_governance_token import IGovernanceToken
from interface_amm import IAMM
from interface_lptoken import ILPToken
from interface_option_token import IOptionToken

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
    with_attr error_message("Unable to initialize governance token"){
        let initial_supply_marek = Uint256(865003000000000000000000, 0); // 10**18, 1 CARM
        // TODO add all recipients and precise amts
        let (governance_address) = get_contract_address();
        const recipient_1 = 0x0011d341c6e841426448ff39aa443a6dbb428914e05ba2259463c18308b86233; // Marek
        IGovernanceToken.initializer(
            contract_address=governance_token_addr,
            name='Carmine token',
            symbol='CARM',
            decimals=18,
            initial_supply=initial_supply_marek,
            recipient=recipient_1,
            proxy_admin=governance_address
        );
        let supply_ondra = Uint256(290992000000000000000000, 0);
        IGovernanceToken.mint(contract_address=governance_token_addr, to=0x0583a9d956d65628f806386ab5b12dccd74236a3c6b930ded9cf3c54efc722a1, amount=supply_ondra); // Ondra
        let supply_andrej = Uint256(149712000000000000000000, 0);
        IGovernanceToken.mint(contract_address=governance_token_addr, to=0x06717eaf502baac2b6b2c6ee3ac39b34a52e726a73905ed586e757158270a0af, amount=supply_andrej); // Andrej
        let supply_david = Uint256(141747000000000000000000, 0);
        IGovernanceToken.mint(contract_address=governance_token_addr, to=0x03d1525605db970fa1724693404f5f64cba8af82ec4aab514e6ebd3dec4838ad, amount=supply_david); // David
        let supply_katsu = Uint256(59311000000000000000000, 0);
        IGovernanceToken.mint(contract_address=governance_token_addr, to=0x04d2FE1Ff7c0181a4F473dCd982402D456385BAE3a0fc38C49C0A99A620d1abe, amount=supply_katsu); // Katsu
    }
    // set investor_voting_power, total_investor_distributed_power
    //investor_voting_power.write(0x001dd8e12b10592676e109c85d6050bdc1e17adf1be0573a089e081c3c260ed9, 10); // Ondra plays one investor here
    //investor_voting_power.write(0x028b14F588C3E68DD92067a9D8604709A002Bfd6d0C2c2e8D92a777967B6d2DF, 10); // Marek is another investor
    //total_investor_distributed_power.write(0);

    // Initialize AMM
    with_attr error_message("Unable to initialize AMM"){
        IAMM.initializer(contract_address=amm_addr, proxy_admin=governance_address);
        IAMM.set_max_option_size_percent_of_voladjspd(contract_address=amm_addr, max_opt_size_as_perc_of_vol_adjspd=30);
    }

    // TESTNET
    //const USDC_addr = 0x5a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426; // TESTNET, quote token
    //const ETH_addr = 0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
    // MAINNET
    const USDC_addr = 0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8;
    const ETH_addr = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

    let ZERO = Uint256(0, 0);

    // deploy call pool ETH lptoken
    with_attr error_message("Unable to deploy call pool"){
        with_attr error_message("Unable to deploy lptoken via generic proxy"){
            let (eth_lpt_addr) = deploy_via_proxy(
                proxy_class=proxy_class,
                impl_class=lpt_class,
                salt=salt
            );
        }
        with_attr error_message("Unable to initialize lptoken"){
            ILPToken.initializer(
                contract_address=eth_lpt_addr,
                name='Carmine ETH/USDC call pool',
                symbol='C-ETHUSDC-C',
                proxy_admin=governance_address,
                owner=amm_addr
            );
        }
        // initialize ETH call pool
        const ETH_volatility_adjustment_speed = 34587645138205409280; // 15*2**61 = 15 ETH
        let ETH_max_lpool_balance = Uint256(low=30000000000000000000,high=0); // 30 ETH 
        with_attr error_message("Unable to add lptoken"){
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
            name='Carmine ETH/USDC put pool',
            symbol='C-ETHUSDC-P',
            proxy_admin=governance_address,
            owner=amm_addr
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
    const EXPIRY_20APR23 = 1682035199; // 2023-04-20 23:59:59 UTC
    const STRIKE_1800 = 4150517416584649113600; // 1800*2**61
    const STRIKE_1900 = 4381101717506018508800; // 1900*2**61
    const STRIKE_2000 = 4611686018427387904000; // 2000*2**61
    const VOLATILITY_60 = 138350580552821637120;
    const VOLATILITY_56_5 = 130280130020573708288;
    const VOLATILITY_58 = 133738894534394249216;

    with_attr error_message("Failed to add options"){
        add_option(
            name='ETHUSDC-20APR23-1900-LONG-CALL',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_LONG,
            maturity=EXPIRY_20APR23,
            strike_price=STRIKE_1900,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_CALL,
            lptoken_address=eth_lpt_addr,
            initial_volatility=VOLATILITY_56_5,
        );

        add_option(
            name='ETHUSDC-20APR23-1900-SHORT-CALL',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_SHORT,
            maturity=EXPIRY_20APR23,
            strike_price=STRIKE_1900,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_CALL,
            lptoken_address=eth_lpt_addr,
            initial_volatility=VOLATILITY_56_5,
        );

        add_option(
            name='ETHUSDC-20APR23-2000-LONG-CALL',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_LONG,
            maturity=EXPIRY_20APR23,
            strike_price=STRIKE_2000,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_CALL,
            lptoken_address=eth_lpt_addr,
            initial_volatility=VOLATILITY_58,
        );

        add_option(
            name='ETHUSDC-20APR23-2000-SHORT-CALL',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_SHORT,
            maturity=EXPIRY_20APR23,
            strike_price=STRIKE_2000,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_CALL,
            lptoken_address=eth_lpt_addr,
            initial_volatility=VOLATILITY_58,
        );

        add_option(
            name='ETHUSDC-20APR23-1900-LONG-PUT',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_LONG,
            maturity=EXPIRY_20APR23,
            strike_price=STRIKE_1900,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_PUT,
            lptoken_address=usdc_lpt_addr,
            initial_volatility=VOLATILITY_56_5,
        );

        add_option(
            name='ETHUSDC-20APR23-1900-SHORT-PUT',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_SHORT,
            maturity=EXPIRY_20APR23,
            strike_price=STRIKE_1900,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_PUT,
            lptoken_address=usdc_lpt_addr,
            initial_volatility=VOLATILITY_56_5,
        );

        add_option(
            name='ETHUSDC-20APR23-1800-LONG-PUT',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_LONG,
            maturity=EXPIRY_20APR23,
            strike_price=STRIKE_1800,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_PUT,
            lptoken_address=usdc_lpt_addr,
            initial_volatility=VOLATILITY_56_5,
        );

        add_option(
            name='ETHUSDC-20APR23-1800-SHORT-PUT',
            proxy_class=proxy_class,
            opt_class=opt_class,
            salt=salt,
            governance_address=governance_address,
            amm_address=amm_addr,
            option_side=TRADE_SIDE_SHORT,
            maturity=EXPIRY_20APR23,
            strike_price=STRIKE_1800,
            quote_token_address=USDC_addr,
            base_token_address=ETH_addr,
            option_type=OPTION_PUT,
            lptoken_address=usdc_lpt_addr,
            initial_volatility=VOLATILITY_56_5,
        );
    }

    return ();
}


@external
func add_0806_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    alloc_locals;

    let (added_already) = proposal_initializer_run.read(prop_id=9);
    with_attr error_message("Options added already") {
        assert added_already = FALSE;
    }
    proposal_initializer_run.write(prop_id=9, value=1);

    const proxy_class = 0x00eafb0413e759430def79539db681f8a4eb98cf4196fe457077d694c6aeeb82;
    const opt_class = 0x5ce3a80daeb5b7a766df9b41ca8d9e52b6b0a045a0d2ced72f43d4dd2f93b10;

    let (governance_address_here) = governance_token_address.read();
    local governance_address = governance_address_here;
    let (amm_addr_here) = amm_address.read();
    local amm_addr = amm_addr_here;
    let eth_lpt_addr = 0x7aba50fdb4e024c1ba63e2c60565d0fd32566ff4b18aa5818fc80c30e749024;
    let usdc_lpt_addr = 0x18a6abca394bd5f822cfa5f88783c01b13e593d1603e7b41b00d31d2ea4827a;

    const salt = 080623420420421; // new salt for these options

    const STRIKE_1700 = 3919933115663279718400; // 1700*2**61
    const STRIKE_1800 = 4150517416584649113600; // 1800*2**61
    const STRIKE_1900 = 4381101717506018508800; // 1900*2**61

    const EXPIRY_08JUN23 = 1686268799; // Thu Jun 08 2023 23:59:59 GMT+0000

    const VOLATILITY_38 = 87622034350120370176;
    const VOLATILITY_37 = 85316191340906676224;
    const VOLATILITY_43 = 99151249396188839936;

    const USDC_addr = 0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8;
    const ETH_addr = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

    add_option(
        name='ETHUSDC-08JUN23-1800-LONG-CALL',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_LONG,
        maturity=EXPIRY_08JUN23,
        strike_price=STRIKE_1800,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_CALL,
        lptoken_address=eth_lpt_addr,
        initial_volatility=VOLATILITY_38,
    );

    add_option(
        name='ETHUSDC-08JUN23-1800-SHORT-CALL',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_SHORT,
        maturity=EXPIRY_08JUN23,
        strike_price=STRIKE_1800,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_CALL,
        lptoken_address=eth_lpt_addr,
        initial_volatility=VOLATILITY_38,
    );

    add_option(
        name='ETHUSDC-08JUN23-1900-LONG-CALL',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_LONG,
        maturity=EXPIRY_08JUN23,
        strike_price=STRIKE_1900,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_CALL,
        lptoken_address=eth_lpt_addr,
        initial_volatility=VOLATILITY_37,
    );

    add_option(
        name='ETHUSDC-08JUN23-1900-SHORT-CALL',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_SHORT,
        maturity=EXPIRY_08JUN23,
        strike_price=STRIKE_1900,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_CALL,
        lptoken_address=eth_lpt_addr,
        initial_volatility=VOLATILITY_37,
    );

    add_option(
        name='ETHUSDC-08JUN23-1800-LONG-PUT',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_LONG,
        maturity=EXPIRY_08JUN23,
        strike_price=STRIKE_1800,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_PUT,
        lptoken_address=usdc_lpt_addr,
        initial_volatility=VOLATILITY_38,
    );

    add_option(
        name='ETHUSDC-08JUN23-1800-SHORT-PUT',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_SHORT,
        maturity=EXPIRY_08JUN23,
        strike_price=STRIKE_1800,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_PUT,
        lptoken_address=usdc_lpt_addr,
        initial_volatility=VOLATILITY_38,
    );

    add_option(
        name='ETHUSDC-08JUN23-1700-LONG-PUT',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_LONG,
        maturity=EXPIRY_08JUN23,
        strike_price=STRIKE_1700,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_PUT,
        lptoken_address=usdc_lpt_addr,
        initial_volatility=VOLATILITY_43,
    );

    add_option(
        name='ETHUSDC-08JUN23-1700-SHORT-PUT',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_SHORT,
        maturity=EXPIRY_08JUN23,
        strike_price=STRIKE_1700,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_PUT,
        lptoken_address=usdc_lpt_addr,
        initial_volatility=VOLATILITY_43,
    );

    return ();
}


@external
func add_1506_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    alloc_locals;

    let (added_already) = proposal_initializer_run.read(prop_id=9150623);
    with_attr error_message("Options added already") {
        assert added_already = FALSE;
    }
    proposal_initializer_run.write(prop_id=9150623, value=1);

    const proxy_class = 0x00eafb0413e759430def79539db681f8a4eb98cf4196fe457077d694c6aeeb82;
    const opt_class = 0x5ce3a80daeb5b7a766df9b41ca8d9e52b6b0a045a0d2ced72f43d4dd2f93b10;

    let (governance_address_here) = governance_token_address.read();
    local governance_address = governance_address_here;
    let (amm_addr_here) = amm_address.read();
    local amm_addr = amm_addr_here;
    let eth_lpt_addr = 0x7aba50fdb4e024c1ba63e2c60565d0fd32566ff4b18aa5818fc80c30e749024;
    let usdc_lpt_addr = 0x18a6abca394bd5f822cfa5f88783c01b13e593d1603e7b41b00d31d2ea4827a;

    const salt = 150623420420421; // new salt for these options

    const STRIKE_1700 = 3919933115663279718400; // 1700*2**61
    const STRIKE_1800 = 4150517416584649113600; // 1800*2**61
    const STRIKE_1900 = 4381101717506018508800; // 1900*2**61

    const EXPIRY_15JUN23 = 1686873599;

    const VOLATILITY_39_5 = 91080798863940911104;
    const VOLATILITY_38 = 87622034350120370176;
    const VOLATILITY_43 = 99151249396188839936;

    const USDC_addr = 0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8;
    const ETH_addr = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

    add_option(
        name='ETHUSDC-15JUN23-1800-LONG-CALL',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_LONG,
        maturity=EXPIRY_15JUN23,
        strike_price=STRIKE_1800,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_CALL,
        lptoken_address=eth_lpt_addr,
        initial_volatility=VOLATILITY_39_5,
    );

    add_option(
        name='ETHUSDC-15JUN23-1800-SHORT-CALL',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_SHORT,
        maturity=EXPIRY_15JUN23,
        strike_price=STRIKE_1800,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_CALL,
        lptoken_address=eth_lpt_addr,
        initial_volatility=VOLATILITY_39_5,
    );

    add_option(
        name='ETHUSDC-15JUN23-1900-LONG-CALL',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_LONG,
        maturity=EXPIRY_15JUN23,
        strike_price=STRIKE_1900,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_CALL,
        lptoken_address=eth_lpt_addr,
        initial_volatility=VOLATILITY_38,
    );

    add_option(
        name='ETHUSDC-15JUN23-1900-SHORT-CALL',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_SHORT,
        maturity=EXPIRY_15JUN23,
        strike_price=STRIKE_1900,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_CALL,
        lptoken_address=eth_lpt_addr,
        initial_volatility=VOLATILITY_38,
    );

    add_option(
        name='ETHUSDC-15JUN23-1800-LONG-PUT',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_LONG,
        maturity=EXPIRY_15JUN23,
        strike_price=STRIKE_1800,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_PUT,
        lptoken_address=usdc_lpt_addr,
       initial_volatility=VOLATILITY_39_5,
    );

    add_option(
        name='ETHUSDC-15JUN23-1800-SHORT-PUT',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_SHORT,
        maturity=EXPIRY_15JUN23,
        strike_price=STRIKE_1800,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_PUT,
        lptoken_address=usdc_lpt_addr,
        initial_volatility=VOLATILITY_39_5,
    );

    add_option(
        name='ETHUSDC-15JUN23-1700-LONG-PUT',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_LONG,
        maturity=EXPIRY_15JUN23,
        strike_price=STRIKE_1700,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_PUT,
        lptoken_address=usdc_lpt_addr,
        initial_volatility=VOLATILITY_43,
    );

    add_option(
        name='ETHUSDC-15JUN23-1700-SHORT-PUT',
        proxy_class=proxy_class,
        opt_class=opt_class,
        salt=salt,
        governance_address=governance_address,
        amm_address=amm_addr,
        option_side=TRADE_SIDE_SHORT,
        maturity=EXPIRY_15JUN23,
        strike_price=STRIKE_1700,
        quote_token_address=USDC_addr,
        base_token_address=ETH_addr,
        option_type=OPTION_PUT,
        lptoken_address=usdc_lpt_addr,
        initial_volatility=VOLATILITY_43,
    );

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
    // 0.5 proposal is considered passed as soon as 50 % of eligible voters voted for it
    // 1.0 mainnet
    // 1.0.1 fix bug in lptoken and optoken ownership
    // 1.0.2 set max option size as percent of voladjspd
    // 1.1 redeploy with mainnet launch imminent
    // 1.2 add options expiring 
    let version = '1.2';
    return (version = version);
}
