%lang starknet

from interfaces.interface_lptoken import ILPToken
from interfaces.interface_amm import IAMM

from starkware.cairo.common.cairo_builtins import HashBuiltin
from math64x61 import Math64x61


namespace AdditionOfLPTokens {
    func lpt_attrs{syscall_ptr: felt*, range_check_ptr}() {

        alloc_locals;

        let strike_price = Math64x61.fromFelt(1500);
        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar amm_addr;
        tempvar maturity;
        tempvar opt_long_call_addr;
        tempvar opt_short_call_addr;
        tempvar opt_long_put_addr;
        tempvar opt_short_put_addr;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
            ids.maturity = context.expiry_0

            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_call_addr = context.opt_short_call_addr_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0
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

        let (opt_address_long_call) = IAMM.get_option_token_address(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr,
            option_side = 0,
            maturity = maturity,
            strike_price = strike_price
        );
        assert opt_address_long_call = opt_long_call_addr;
        
        let (opt_address_short_call) = IAMM.get_option_token_address(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr,
            option_side = 1,
            maturity = maturity,
            strike_price = strike_price
        );
        assert opt_address_short_call = opt_short_call_addr;

        let (opt_address_long_put) = IAMM.get_option_token_address(
            contract_address = amm_addr,
            lptoken_address = lpt_put_addr,
            option_side = 0,
            maturity = maturity,
            strike_price = strike_price
        );
        assert opt_address_long_put = opt_long_put_addr;

        let (opt_address_short_put) = IAMM.get_option_token_address(
            contract_address = amm_addr,
            lptoken_address = lpt_put_addr,
            option_side = 1,
            maturity = maturity,
            strike_price = strike_price
        );
        assert opt_address_short_put = opt_short_put_addr;

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

        IAMM.add_lptoken(
            contract_address=amm_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=2, // option with type '2' does not exist
            lptoken_address=lpt_call_addr,
            volatility_adjustment_speed = 1 // Does not matter here
        );

        return ();
    }
}
