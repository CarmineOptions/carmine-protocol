%lang starknet

from interface_governance_token import IGovernanceToken
from interface_amm import IAMM
from interface_lptoken import ILPToken
from interface_option_token import IOptionToken

from types import Address, PropDetails, BlockNumber, VoteStatus, ContractType, VoteCounts, OptionType, Math64x61_, OptionSide, Int

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address, deploy
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.alloc import alloc

func add_option{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    name: felt,
    proxy_class: felt,
    opt_class: felt,
    salt: felt,
    governance_address: Address,
    amm_address: Address,
    option_side: OptionSide,
    maturity: Int,
    strike_price: Math64x61_,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    lptoken_address: Address,
    initial_volatility: Math64x61_
) {
    let custom_salt = salt + strike_price;
    let custom_salt = custom_salt + maturity;
    let custom_salt = custom_salt + option_type;
    let custom_salt = custom_salt + option_side;
    let custom_salt = custom_salt + lptoken_address;

    let (optoken_addr) = deploy_via_proxy(
        proxy_class=proxy_class,
        impl_class=opt_class,
        salt=salt
    );
    
    with_attr error_message("add_option: failed to initialize optoken"){
        IOptionToken.initializer(
            contract_address=optoken_addr,
            name=name,
            symbol='C-OPT',
            proxy_admin=governance_address,
            quote_token_address=quote_token_address,
            base_token_address=base_token_address,
            option_type=option_type,
            strike_price=strike_price,
            maturity=maturity,
            side=option_side
        );
    }

    with_attr error_message("add_option: failed to add option to AMM"){
        IAMM.add_option(
            contract_address=amm_address,
            option_side=option_side,
            maturity=maturity,
            strike_price=strike_price,
            quote_token_address=quote_token_address,
            base_token_address=base_token_address,
            option_type=option_type,
            lptoken_address=lptoken_address,
            option_token_address_=optoken_addr,
            initial_volatility=initial_volatility
        );
    }

    return ();
}

func deploy_via_proxy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    proxy_class: felt,
    impl_class: felt,
    salt: felt
) -> (
    contract_address: felt
) {
    alloc_locals;
    with_attr error_message("deploy_via_proxy deploy syscall failed") {
        with_attr error_message("deploy_via_proxy: failed preparing calldata") {
            let (calldata : felt*) = alloc();
            assert [calldata] = impl_class;
            assert [calldata + 1] = 0;
            assert [calldata + 2] = 0;
            assert [calldata + 3] = 0;
        }
        let curr_salt = salt + impl_class;
        let (contract_address) = deploy(
            class_hash=proxy_class,
            contract_address_salt=curr_salt,
            constructor_calldata_size=4,
            constructor_calldata=calldata,
            deploy_from_zero=FALSE
        );
    }
    return (contract_address = contract_address);
}
