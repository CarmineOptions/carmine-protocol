%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool

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

        local lpt_call_addr;
        local lpt_put_addr;
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

        local lpt_call_addr;
        local lpt_put_addr;
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

    // FIXME: add all of the simple view functions that need setup
}
