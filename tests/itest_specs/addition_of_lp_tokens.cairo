%lang starknet

from interfaces.interface_lptoken import ILPToken
from interfaces.interface_amm import IAMM

from starkware.cairo.common.cairo_builtins import HashBuiltin



namespace AdditionOfLPTokens {
    func lpt_attrs{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME: missing tests for the state storage_vars in AMM (that the opt tokens were correctly
        // added)

        alloc_locals;

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar amm_addr;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
        %}

        let (symbol_call) = ILPToken.symbol(contract_address=lpt_call_addr);
        assert symbol_call = 11;
        let (name_call) = ILPToken.name(contract_address=lpt_call_addr);
        assert name_call = 111;

        let (symbol_put) = ILPToken.symbol(contract_address=lpt_put_addr);
        assert symbol_put = 12;
        let (name_put) = ILPToken.name(contract_address=lpt_put_addr);
        assert name_put = 112;

        let (lptoken_address_0) = IAMM.get_available_lptoken_addresses(
            contract_address=amm_addr,
            order_i=0
        );
        assert lptoken_address_0 = lpt_call_addr;

        let (lptoken_address_1) = IAMM.get_available_lptoken_addresses(
            contract_address=amm_addr,
            order_i=1
        );
        assert lptoken_address_1 = lpt_put_addr;

        let (lptoken_address_2) = IAMM.get_available_lptoken_addresses(
            contract_address=amm_addr,
            order_i=2
        );
        assert lptoken_address_2 = 0;

        return ();
    }

    // FIXME: try to add incorrect lptokens (incorrect input params)
}
