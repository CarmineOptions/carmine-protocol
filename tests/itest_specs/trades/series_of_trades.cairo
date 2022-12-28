%lang starknet

from interface_amm import IAMM
from types import Math64x61_
from constants import EMPIRIC_ORACLE_ADDRESS

from math64x61 import Math64x61


namespace SeriesOfTrades {
    func trade_open{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME: this only tests the premia and not other variables/storage_vars
        alloc_locals;

        // 12 hours after listing, 12 hours before expir
        %{ warp(1000000000 + 60*60*12, target_contract_address = context.amm_addr) %}

        tempvar lpt_call_addr;
        tempvar opt_long_call_addr;
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;

        tempvar expiry;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address

            ids.expiry = context.expiry_0
        %}

        let strike_price = Math64x61.fromFelt(1500);
        let one_option_size = 1 * 10**18;

        tempvar tmp_address = 0x446812bac98c08190dee8967180f4e3cdcd1db9373ca269904acb17f67f7093;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [145000000000, 0, 0, 0, 0]  # mock terminal ETH price at 1450
            )
        %}

        // First trade, LONG CALL
        let (premia_long_call: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            desired_price=0,
            max_price_diff=0,
            should_check_slippage=0, // Skip slippage check
        );

        assert premia_long_call = 2020558154346487; // approx 0.00087 ETH, or 1.22 USD

        // Second trade, SHORT CALL
        let (premia_short_call: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            desired_price=0,
            max_price_diff=0,
            should_check_slippage=0, // Skip slippage check
        );

        assert premia_short_call = 2020760452941187; // approx the same as before, but slightly higher, since vol. was increased 
                                                     // with previous trade
        // Second trade, PUT LONG
        let (premia_long_put: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            desired_price=0,
            max_price_diff=0,
            should_check_slippage=0, // Skip slippage check
        );

        assert premia_long_put = 234655350073966452800;
        
        // Second trade, PUT SHORT
        let (premia_short_put: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            desired_price=0,
            max_price_diff=0,
            should_check_slippage=0, // Skip slippage check
        );

        assert premia_short_put = 234722763583748232400;
        %{
            # optional, but included for completeness and extensibility
            stop_prank_amm()
            stop_mock_current_price()
            stop_mock_terminal_price()
        %}
        return ();
    }

    func trade_close{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME:
            // possibly split into several functions
            // scenarios:
                // can close trade no problem
                // can close part of the trade - no problem
                // is closing trade, but has not enough opt tokens for the selected option size
                // there is not enough unlocked capital to pay off premium - user long
                    // if there is not locked capital for this option (enough position)
                    //   -> this works only for user being long - pool should first unlock capital then pay premia
                    // if there is not enough locked capital -> will most likely fail
                // user short
                    // ...
        return ();
    }

    func trade_settle{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME
        // should work always... except for incorrect input params 
        // scenarios:
            // settle only part
            // settle before pool settles
            // settle everything

        return ();
    }

    func test_slippage{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        // 12 hours after listing, 12 hours before expir
        %{ warp(1000000000 + 60*60*12, target_contract_address = context.amm_addr) %}

        // tempvar lpt_call_addr;
        // tempvar opt_long_call_addr;
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;

        tempvar expiry;
        %{
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address

            ids.expiry = context.expiry_0
        %}

        let strike_price = Math64x61.fromFelt(1500);
        let one_option_size = 1 * 10**18;

        tempvar tmp_address = 0x446812bac98c08190dee8967180f4e3cdcd1db9373ca269904acb17f67f7093;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [145000000000, 0, 0, 0, 0]  # mock terminal ETH price at 1450
            )
        %}

        // First trade, LONG CALL, should pass
        let (_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            desired_price=2020558154346487,
            max_price_diff=101027907717324, // Around 5%
            should_check_slippage=1, 
        );
        // Second trade, SHORT CALL, should pass
        let (_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            desired_price=1939930034823539,
            max_price_diff=96996501741176, // Around 5%
            should_check_slippage=1, 
        );
        // Second trade, PUT LONG, should pass
        let (_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            desired_price=241695010576185458688,
            max_price_diff=11732767503698323456, // Around 5%
            should_check_slippage=1, 
        );

        %{
            # Following trade will fail
            expect_revert(
                error_message = "Current price varies too much from desired_price"
            )
        %}
        
        // Second trade, PUT SHORT, should NOT pass
        let (_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            desired_price=211250487225373425664,
            max_price_diff=10562524361268672512, // Around 5%
            should_check_slippage=1,
        );

        return ();
    }
}
