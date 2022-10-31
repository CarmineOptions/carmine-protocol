%lang starknet

from interface_lptoken import ILPToken



namespace AdditionOfLPTokens {
    func lpt_attrs{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME: missing tests for the state storage_vars in AMM (that the opt tokens were correctly
        // added)
        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
        %}

        let (symbol_call) = ILPToken.symbol(contract_address=lpt_call_addr);
        assert symbol_call = 11;
        let (name_call) = ILPToken.name(contract_address=lpt_call_addr);
        assert name_call = 111;

        let (symbol_put) = ILPToken.symbol(contract_address=lpt_put_addr);
        assert symbol_put = 12;
        let (name_put) = ILPToken.name(contract_address=lpt_put_addr);
        assert name_put = 112;
        return ();
    }
}
