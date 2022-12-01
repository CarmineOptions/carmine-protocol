%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool

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

        let (lptoken_address_0) = ILiquidityPool.get_available_lptoken_addresses(
            contract_address=amm_addr,
            order_i=0
        );
        assert lptoken_address_0 = lpt_call_addr;

        let (lptoken_address_1) = ILiquidityPool.get_available_lptoken_addresses(
            contract_address=amm_addr,
            order_i=1
        );
        assert lptoken_address_1 = lpt_put_addr;

        let (lptoken_address_2) = ILiquidityPool.get_available_lptoken_addresses(
            contract_address=amm_addr,
            order_i=2
        );
        assert lptoken_address_2 = 0;

        return ();
    }

    func add_incorrect_lpt{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar lpt_call_addr;

        %{
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.lpt_call_addr = context.lpt_call_addr
        %}

        %{ expect_revert(error_message ="Received unknown option type(=2) in add_lptoken") %}

        ILiquidityPool.add_lptoken(
            contract_address=amm_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=2, // option with type '2' does not exist
            lptoken_address=lpt_call_addr
        );

        return ();
    }
}
