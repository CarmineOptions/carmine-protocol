%lang starknet

from interface_option_token import IOptionToken
from interface_liquidity_pool import ILiquidityPool
from math64x61 import Math64x61



namespace AdditionOfOptionTokens {
    func option_attrs{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

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

    func add_incorrect_option{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        tempvar amm_addr;
        tempvar expiry;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar lpt_call_addr;
        tempvar opt_long_call_addr;

        %{
            ids.amm_addr = context.amm_addr
            ids.expiry = context.expiry_0
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.lpt_call_addr = context.lpt_call_addr
            ids.opt_long_call_addr = context.opt_long_call_addr_0
        %}
        
        // Strike price is wrong
        let strike_price = Math64x61.fromFelt(1200);

        let hundred_m64x61 = Math64x61.fromFelt(100);

        %{ expect_revert(error_message = "Given inputs for add_option function do not match the option token") %}
        
        ILiquidityPool.add_option(
            contract_address=amm_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type = 0,
            lptoken_address=lpt_call_addr,
            option_token_address_=opt_long_call_addr,
            initial_volatility=hundred_m64x61
        );

        return ();
    }
}