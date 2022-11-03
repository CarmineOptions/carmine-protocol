%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool

from math64x61 import Math64x61
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_le



func get_array_element{syscall_ptr: felt*, range_check_ptr}(
    order_i: felt, array_len: felt, array: felt*
) -> (
    element: felt
) {
    alloc_locals;

    with_attr error_message("order_i > array_len, {order_i} {array_len}"){
        assert_le(order_i, array_len);
    }

    if (order_i == 0) {
        return ([array], );
    }

    return get_array_element(order_i - 1, array_len - 1, array + 1);
}


namespace LPBasicViewFunctions {
    func get_all_lptoken_addresses{syscall_ptr: felt*, range_check_ptr}() {

        alloc_locals;

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar amm_addr;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
        %}

        let (lptoken_addresses_len, lptoken_addresses) = ILiquidityPool.get_all_lptoken_addresses(
            contract_address=amm_addr,
        );
        assert lptoken_addresses_len = 2;

        let (first_address) = get_array_element(0, lptoken_addresses_len, lptoken_addresses);
        let (second_address) = get_array_element(1, lptoken_addresses_len, lptoken_addresses);
        assert first_address = lpt_call_addr;
        assert second_address = lpt_put_addr;

        return ();
    }


    func get_available_lptoken_addresses{syscall_ptr: felt*, range_check_ptr}() {

        alloc_locals;

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar amm_addr;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
        %}

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


    func _add_expired_option{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        let strike_price = Math64x61.fromFelt(1500);
        let hundred_m64x61 = Math64x61.fromFelt(100);

        tempvar opt_long_call_addr_1;
        local amm_addr;
        local side_long;
        local expiry;
        local myusd_address;
        local myusd_address;
        local optype_call;
        local lpt_call_addr;
        local opt_long_call_addr;

        %{
            expiry = int(1000000000 - 60*60*24)
            side_long = 0
            optype_call = 0

            context.opt_long_call_addr_1 = deploy_contract(
                "./contracts/option_token.cairo",
                [1234, 14, 18, 0, 0, context.admin_address, context.amm_addr, context.myusd_address, context.myeth_address, optype_call, ids.strike_price, expiry, side_long]
            ).contract_address
            ids.opt_long_call_addr_1 = context.opt_long_call_addr_1


            ids.amm_addr = context.amm_addr
            ids.side_long = side_long
            ids.expiry = expiry
            ids.myusd_address = context.myusd_address
            ids.myusd_address = context.myusd_address
            ids.optype_call = optype_call
            ids.lpt_call_addr = context.lpt_call_addr
            ids.opt_long_call_addr = context.opt_long_call_addr_0

            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        %}

        ILiquidityPool.add_option(
            contract_address=amm_addr,
            option_side=side_long,
            maturity=expiry,
            strike_price=strike_price,
            quote_token_address=myusd_address,
            base_token_address=myusd_address,
            option_type=optype_call,
            lptoken_address=lpt_call_addr,
            option_token_address_=opt_long_call_addr,
            initial_volatility=hundred_m64x61
        );

        %{ stop_prank_amm() %}
        return ();
    }


    func get_all_options{syscall_ptr: felt*, range_check_ptr}() {

        alloc_locals;

        _add_expired_option();

        local opt_long_call_addr;
        local opt_long_call_addr_1;
        local opt_short_call_addr;
        local opt_long_put_addr;
        local opt_short_put_addr;

        local lpt_call_addr;
        local lpt_put_addr;
        local amm_addr;
        %{
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_long_call_addr_1 = context.opt_long_call_addr_1
            ids.opt_short_call_addr = context.opt_short_call_addr_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0

            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr

            stop_warp = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr)
        %}

        let (option_call_addresses_len, option_call_addresses) = ILiquidityPool.get_all_options(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );

        let (option_put_addresses_len, option_put_addresses) = ILiquidityPool.get_all_options(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );

        // *6 because the Option struct has 6 elements
        assert option_call_addresses_len = 3*6;
        assert option_put_addresses_len = 2*6;

        let (option_call_address_0) = get_array_element(0, option_call_addresses_len, option_call_addresses);
        let (option_call_address_1) = get_array_element(1, option_call_addresses_len, option_call_addresses);
        let (option_call_address_2) = get_array_element(2, option_call_addresses_len, option_call_addresses);

        let (option_put_address_0) = get_array_element(0, option_put_addresses_len, option_put_addresses);
        let (option_put_address_1) = get_array_element(1, option_put_addresses_len, option_put_addresses);
        
        assert opt_long_call_addr = option_call_address_0;
        assert opt_short_call_addr = option_call_address_1;
        assert opt_long_call_addr_1 = option_call_address_2;

        assert opt_long_put_addr = option_put_address_0;
        assert opt_short_put_addr = option_put_address_1;

        %{
            stop_warp()
        %}

        return ();
    }


    func get_all_non_expired_options_with_premia{syscall_ptr: felt*, range_check_ptr}() {

        alloc_locals;

        _add_expired_option();

        local opt_long_call_addr;
        local opt_long_call_addr_1;
        local opt_short_call_addr;
        local opt_long_put_addr;
        local opt_short_put_addr;

        local lpt_call_addr;
        local lpt_put_addr;
        local amm_addr;
        %{
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_long_call_addr_1 = context.opt_long_call_addr_1
            ids.opt_short_call_addr = context.opt_short_call_addr_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0

            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr

            stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr)
        %}

        let (option_call_addresses_len, option_call_addresses) = ILiquidityPool.get_all_non_expired_options_with_premia(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );

        let (option_put_addresses_len, option_put_addresses) = ILiquidityPool.get_all_non_expired_options_with_premia(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        
        assert option_call_addresses_len = 2;
        assert option_put_addresses_len = 2;

        let (option_call_address_0) = get_array_element(0, option_call_addresses_len, option_call_addresses);
        let (option_call_address_1) = get_array_element(1, option_call_addresses_len, option_call_addresses);

        let (option_put_address_0) = get_array_element(0, option_put_addresses_len, option_put_addresses);
        let (option_put_address_1) = get_array_element(1, option_put_addresses_len, option_put_addresses);
        
        assert opt_long_call_addr = option_call_address_0;
        assert opt_short_call_addr = option_call_address_1;

        assert opt_long_put_addr = option_put_address_0;
        assert opt_short_put_addr = option_put_address_1;

        %{
            stop_warp_1()
            stop_warp_2 = warp(1000000000 + 60*60*36, target_contract_address=ids.amm_addr)
        %}

        let (option_call_addresses_len_empty, option_call_addresses_empty) = ILiquidityPool.get_all_non_expired_options_with_premia(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );

        let (option_put_addresses_len_empty, option_put_addresses_empty) = ILiquidityPool.get_all_non_expired_options_with_premia(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        
        assert option_call_addresses_len_empty = 0;
        assert option_put_addresses_len_empty = 2;

        %{
            stop_warp_2()
        %}

        return ();
    }


    // FIXME: add all of the simple view functions that need setup
}
