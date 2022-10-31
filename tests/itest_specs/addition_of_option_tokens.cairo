%lang starknet

from interface_option_token import IOptionToken



namespace AdditionOfOptionTokens {
    func option_attrs{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME: missing tests for the state storage_vars in AMM (that the lp tokens were correctly
        // added and pools correctly created)
        tempvar opt_long_call_addr;
        tempvar opt_short_call_addr;
        tempvar opt_long_put_addr;
        tempvar opt_short_put_addr;
        tempvar base_addr;
        tempvar quote_addr;
        %{
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_call_addr = context.opt_short_call_addr_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0
            ids.base_addr = context.myeth_address
            ids.quote_addr = context.myusd_address
        %}

        let (quote_address_call_long) = IOptionToken.quote_token_address(contract_address=opt_long_call_addr);
        assert quote_address_call_long = quote_addr;
        let (base_address_call_long) = IOptionToken.base_token_address(contract_address=opt_long_call_addr);
        assert base_address_call_long = base_addr;
        let (option_type_call_long) = IOptionToken.option_type(contract_address=opt_long_call_addr);
        assert option_type_call_long = 0;

        let (quote_address_call_short) = IOptionToken.quote_token_address(contract_address=opt_short_call_addr);
        assert quote_address_call_short = quote_addr;
        let (base_address_call_short) = IOptionToken.base_token_address(contract_address=opt_short_call_addr);
        assert base_address_call_short = base_addr;
        let (option_type_call_short) = IOptionToken.option_type(contract_address=opt_short_call_addr);
        assert option_type_call_short = 0;

        let (quote_address_put_long) = IOptionToken.quote_token_address(contract_address=opt_long_put_addr);
        assert quote_address_put_long = quote_addr;
        let (base_address_put_long) = IOptionToken.base_token_address(contract_address=opt_long_put_addr);
        assert base_address_put_long = base_addr;
        let (option_type_put_long) = IOptionToken.option_type(contract_address=opt_long_put_addr);
        assert option_type_put_long = 1;

        let (quote_address_put_short) = IOptionToken.quote_token_address(contract_address=opt_short_put_addr);
        assert quote_address_put_short = quote_addr;
        let (base_address_put_short) = IOptionToken.base_token_address(contract_address=opt_short_put_addr);
        assert base_address_put_short = base_addr;
        let (option_type_put_short) = IOptionToken.option_type(contract_address=opt_short_put_addr);
        assert option_type_put_short = 1;

        return ();
    }
}