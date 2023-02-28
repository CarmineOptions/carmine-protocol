%lang starknet

from constants import EMPIRIC_ORACLE_ADDRESS
from interfaces.interface_lptoken import ILPToken
from interfaces.interface_amm import IAMM
from contracts.types import Option

from math64x61 import Math64x61
from openzeppelin.token.erc20.IERC20 import IERC20
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.uint256 import Uint256



func get_array_element{syscall_ptr: felt*, range_check_ptr}(
    order_i: felt, array_len: felt, array: felt*
) -> felt {
    alloc_locals;

    with_attr error_message("order_i > array_len, {order_i} {array_len}"){
        assert_le(order_i, array_len);
    }

    if (order_i == 0) {
        return [array];
    }

    return get_array_element(order_i - 1, array_len - 1, array + 1);
}


namespace LPBasicViewFunctions {
    func get_all_lptoken_addresses{syscall_ptr: felt*, range_check_ptr}() {

        alloc_locals;

        local lpt_call_addr;
        local lpt_put_addr;
        local amm_addr;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
        %}

        let (lptoken_addresses_len, lptoken_addresses) = IAMM.get_all_lptoken_addresses(
            contract_address=amm_addr,
        );
        assert lptoken_addresses_len = 2;

        let first_address = get_array_element(0, lptoken_addresses_len, lptoken_addresses);
        let second_address = get_array_element(1, lptoken_addresses_len, lptoken_addresses);
        assert first_address = lpt_call_addr;
        assert second_address = lpt_put_addr;

        return ();
    }


    func get_available_lptoken_addresses{syscall_ptr: felt*, range_check_ptr}() {

        alloc_locals;

        local lpt_call_addr;
        local lpt_put_addr;
        local amm_addr;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
        %}

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


    func _add_expired_option{syscall_ptr: felt*, range_check_ptr}() {

        alloc_locals;

        local strike_price = Math64x61.fromFelt(1500);
        local hundred_m64x61 = Math64x61.fromFelt(100);

        local opt_long_call_addr_1;
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

            ids.amm_addr = context.amm_addr
            ids.side_long = side_long
            ids.expiry = expiry
            ids.myusd_address = context.myusd_address
            ids.myusd_address = context.myusd_address
            ids.optype_call = optype_call
            ids.lpt_call_addr = context.lpt_call_addr
            ids.opt_long_call_addr = context.opt_long_call_addr_0

            stop_warp = warp(1000000000 - 60*60*96, target_contract_address=ids.amm_addr)

            context.opt_long_call_addr_1 = deploy_contract(
                "./contracts/erc20_tokens/option_token.cairo",
                [
                    12345, 14, 18, 0, 0, context.admin_address, context.amm_addr, context.myusd_address,
                    context.myeth_address, optype_call, ids.strike_price, expiry, side_long
                ]
            ).contract_address

            ids.opt_long_call_addr_1 = context.opt_long_call_addr_1
        %}

        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        %}

        IAMM.add_option(
            contract_address=amm_addr,
            option_side=side_long,
            maturity=expiry,
            strike_price=strike_price,
            quote_token_address=myusd_address,
            base_token_address=myusd_address,
            option_type=optype_call,
            lptoken_address=lpt_call_addr,
            option_token_address_=opt_long_call_addr_1,
            initial_volatility=hundred_m64x61
        );

        %{
            stop_warp()
            stop_prank_amm()
        %}
        return ();
    }


    func get_all_options{syscall_ptr: felt*, range_check_ptr}() {
        // There are 3 call options
        //      two with maturity 1000000000 + 60*60*24
        //      one with maturity 1000000000 - 60*60*24
        // There are 2 pyt options both with maturity 1000000000 + 60*60*24
        // All should show

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

        let (option_call_len, option_call_array) = IAMM.get_all_options(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );

        let (option_put_len, option_put_array) = IAMM.get_all_options(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );

        // *6 because the Option struct has 6 elements
        assert option_call_len = 3*6;
        assert option_put_len = 2*6;

        // Calls
        let option_call_side_0 = get_array_element(0, option_call_len, option_call_array);
        let option_call_maturity_0 = get_array_element(1, option_call_len, option_call_array);
        let option_call_strike_0 = get_array_element(2, option_call_len, option_call_array);

        let (call_option_token_address_0) = IAMM.get_option_token_address(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=option_call_side_0,
            maturity=option_call_maturity_0,
            strike_price=option_call_strike_0
        );
        assert call_option_token_address_0 = opt_long_call_addr;

        let option_call_side_1 = get_array_element(6, option_call_len, option_call_array);
        let option_call_maturity_1 = get_array_element(7, option_call_len, option_call_array);
        let option_call_strike_1 = get_array_element(8, option_call_len, option_call_array);
        let (call_option_token_address_1) = IAMM.get_option_token_address(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=option_call_side_1,
            maturity=option_call_maturity_1,
            strike_price=option_call_strike_1
        );
        assert call_option_token_address_1 = opt_short_call_addr;

        let option_call_side_2 = get_array_element(12, option_call_len, option_call_array);
        let option_call_maturity_2 = get_array_element(13, option_call_len, option_call_array);
        let option_call_strike_2 = get_array_element(14, option_call_len, option_call_array);
        let (call_option_token_address_2) = IAMM.get_option_token_address(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=option_call_side_2,
            maturity=option_call_maturity_2,
            strike_price=option_call_strike_2
        );
        assert call_option_token_address_2 = opt_long_call_addr_1;

        // Puts
        let option_put_side_0 = get_array_element(0, option_put_len, option_put_array);
        let option_put_maturity_0 = get_array_element(1, option_put_len, option_put_array);
        let option_put_strike_0 = get_array_element(2, option_put_len, option_put_array);
        let (put_option_token_address_0) = IAMM.get_option_token_address(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=option_put_side_0,
            maturity=option_put_maturity_0,
            strike_price=option_put_strike_0
        );
        assert put_option_token_address_0 = opt_long_put_addr;

        let option_put_side_1 = get_array_element(6, option_put_len, option_put_array);
        let option_put_maturity_1 = get_array_element(7, option_put_len, option_put_array);
        let option_put_strike_1 = get_array_element(8, option_put_len, option_put_array);
        let (put_option_token_address_1) = IAMM.get_option_token_address(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=option_put_side_1,
            maturity=option_put_maturity_1,
            strike_price=option_put_strike_1
        );
        assert put_option_token_address_1 = opt_short_put_addr;

        %{
            stop_warp()
        %}

        return ();
    }


    func get_all_non_expired_options_with_premia{syscall_ptr: felt*, range_check_ptr}() {
        // There are 3 call options
        //      two with maturity 1000000000 + 60*60*24
        //      one with maturity 1000000000 - 60*60*24
        // There are 2 put options both with maturity 1000000000 + 60*60*24
        // Only the options with maturity 1000000000 + 60*60*24 should show -> 2 calls, 2 puts

        alloc_locals;

        _add_expired_option();

        local tmp_address = EMPIRIC_ORACLE_ADDRESS;

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

            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
        %}

        let (option_call_len, option_call_array) = IAMM.get_all_non_expired_options_with_premia(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );

        let (option_put_len, option_put_array) = IAMM.get_all_non_expired_options_with_premia(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );

        // *7 because the OptionWithPremia struct has 7 elements
        assert option_call_len = 2*7;
        assert option_put_len = 2*7;
        
        // Calls
        let option_call_side_0 = get_array_element(0, option_call_len, option_call_array);
        let option_call_maturity_0 = get_array_element(1, option_call_len, option_call_array);
        let option_call_strike_0 = get_array_element(2, option_call_len, option_call_array);
        let option_call_premia_0 = get_array_element(6, option_call_len, option_call_array);

        assert option_call_premia_0 = 2081174898976881;

        let (call_option_token_address_0) = IAMM.get_option_token_address(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=option_call_side_0,
            maturity=option_call_maturity_0,
            strike_price=option_call_strike_0
        );
        assert call_option_token_address_0 = opt_long_call_addr;

        let option_call_side_1 = get_array_element(7, option_call_len, option_call_array);
        let option_call_maturity_1 = get_array_element(8, option_call_len, option_call_array);
        let option_call_strike_1 = get_array_element(9, option_call_len, option_call_array);
        let option_call_premia_1 = get_array_element(13, option_call_len, option_call_array);

        assert option_call_premia_1 = 608622173767232;

        
        let (call_option_token_address_1) = IAMM.get_option_token_address(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=option_call_side_1,
            maturity=option_call_maturity_1,
            strike_price=option_call_strike_1
        );
        assert call_option_token_address_1 = opt_short_call_addr;

        // Puts
        let option_put_side_0 = get_array_element(0, option_put_len, option_put_array);
        let option_put_maturity_0 = get_array_element(1, option_put_len, option_put_array);
        let option_put_strike_0 = get_array_element(2, option_put_len, option_put_array);
        let option_put_premia_0 = get_array_element(6, option_put_len, option_put_array);

        assert option_put_premia_0 = 241695010576185446327;
        
        let (put_option_token_address_0) = IAMM.get_option_token_address(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=option_put_side_0,
            maturity=option_put_maturity_0,
            strike_price=option_put_strike_0
        );
        assert put_option_token_address_0 = opt_long_put_addr;

        let option_put_side_1 = get_array_element(7, option_put_len, option_put_array);
        let option_put_maturity_1 = get_array_element(8, option_put_len, option_put_array);
        let option_put_strike_1 = get_array_element(9, option_put_len, option_put_array);
        let option_put_premia_1 = get_array_element(13, option_put_len, option_put_array);

        assert option_put_premia_1 = 224338456389442822640;     

        let (put_option_token_address_1) = IAMM.get_option_token_address(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=option_put_side_1,
            maturity=option_put_maturity_1,
            strike_price=option_put_strike_1
        );
        assert put_option_token_address_1 = opt_short_put_addr;


        %{
            stop_warp_1()
            stop_mock_current_price()
        %}

        return ();
    }


    func _add_user_position{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        local tmp_address = EMPIRIC_ORACLE_ADDRESS;

        local opt_long_call_addr_1;
        local opt_long_put_addr;

        local amm_addr;
        local admin_address;

        local myusd_addr;
        local myeth_addr;
        local expiry;
        %{
            ids.opt_long_call_addr_1 = context.opt_long_call_addr_1
            ids.opt_long_put_addr = context.opt_long_put_addr_0

            ids.amm_addr = context.amm_addr
            ids.admin_address = context.admin_address

            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.expiry = context.expiry_0

            stop_warp_add_user_position_1 = warp(1000000000 - 60*60*36, target_contract_address=ids.amm_addr)

            stop_mock_current_price_add_user_position = mock_call(
                ids.tmp_address, "get_spot_median", [1400000000000000000000, 18, 0, 0]  # mock current ETH price at 1400
            )
        %}

        let strike_price = Math64x61.fromFelt(1500);
        let one = 10**18;
        let expiry_2 = 1000000000 - 60*60*24;

        // Approve the transactions (trade opens).

        let max_127bit_number = 0x80000000000000000000000000000000;
        let approve_amt = Uint256(low = max_127bit_number, high = max_127bit_number);
        %{
            stop_prank_myeth = start_prank(context.admin_address, context.myeth_address)
        %}
        IERC20.approve(contract_address=myeth_addr, spender=amm_addr, amount=approve_amt);
        %{
            stop_prank_myeth()
            stop_prank_myusd = start_prank(context.admin_address, context.myusd_address)
        %}
        IERC20.approve(contract_address=myusd_addr, spender=amm_addr, amount=approve_amt);

        %{
            stop_prank_myusd()
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        %}

        // Buy the options
        let (premia) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry_2,
            option_side=0,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=230584300921369395200000, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );

        let (premia) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=230584300921369395200000, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );
        %{
            stop_warp_add_user_position_1()
            stop_mock_current_price_add_user_position()
            stop_prank_amm()
        %}

        return ();
    }


    func get_option_with_position_of_user{syscall_ptr: felt*, range_check_ptr}() {
        // There are 3 call options
        //      two with maturity 1000000000 + 60*60*24
        //      one with maturity 1000000000 - 60*60*24
        // There are 2 put options both with maturity 1000000000 + 60*60*24

        // User has position in
        //      call with maturity 1000000000 - 60*60*24
        //      put with maturity 1000000000 + 60*60*24

        alloc_locals;

        _add_expired_option();
        _add_user_position();

        local tmp_address = EMPIRIC_ORACLE_ADDRESS;

        local opt_long_call_addr_1;
        local opt_long_put_addr;

        local lpt_call_addr;
        local lpt_put_addr;
        local amm_addr;
        local admin_address;
        %{
            ids.opt_long_call_addr_1 = context.opt_long_call_addr_1
            ids.opt_long_put_addr = context.opt_long_put_addr_0

            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
            ids.admin_address = context.admin_address

            stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr)

            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [1400000000000000000000, 18, 0, 0]  # mock current ETH price at 1400
            )

            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)

            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_spot_checkpoint_before", [0, 145000000000, 0, 0, 0]  # mock terminal ETH price at 1450
            )
        %}

        let (options_with_position_len, options_with_position) = IAMM.get_option_with_position_of_user(
            contract_address=amm_addr,
            user_address=admin_address
        );

        // *9 because the OptionWithUsersPosition struct has 9 elements
        assert options_with_position_len = 2*9;

        // Options
        let option_side_0 = get_array_element(0, options_with_position_len, options_with_position);
        let option_maturity_0 = get_array_element(1, options_with_position_len, options_with_position);
        let option_strike_0 = get_array_element(2, options_with_position_len, options_with_position);
        let (option_token_address_0) = IAMM.get_option_token_address(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=option_side_0,
            maturity=option_maturity_0,
            strike_price=option_strike_0
        );
        assert option_token_address_0 = opt_long_call_addr_1;

        let option_side_1 = get_array_element(9, options_with_position_len, options_with_position);
        let option_maturity_1 = get_array_element(10, options_with_position_len, options_with_position);
        let option_strike_1 = get_array_element(11, options_with_position_len, options_with_position);
        let (option_token_address_1) = IAMM.get_option_token_address(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=option_side_1,
            maturity=option_maturity_1,
            strike_price=option_strike_1
        );
        assert option_token_address_1 = opt_long_put_addr;

        %{
            stop_warp_1()
            stop_mock_current_price()
            stop_prank_amm()
            stop_mock_terminal_price()
        %}

        return ();
    }

    func get_total_premia{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        local tmp_address = EMPIRIC_ORACLE_ADDRESS;

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;
        tempvar expiry;
        tempvar opt_long_call_addr;

        let strike_price = Math64x61.fromFelt(1500);
        let one = Uint256(1 * 10 ** 18, 0);
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address
            ids.expiry = context.expiry_0
            ids.opt_long_call_addr = context.opt_long_call_addr_0

            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)

            stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr)

            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
        %}

        let option_long_call = Option (
            0, 
            expiry,
            strike_price,
            myusd_addr,
            myeth_addr,
            0,
        );

        let option_short_call = Option (
            1, 
            expiry,
            strike_price,
            myusd_addr,
            myeth_addr,
            0,
        );
        
        let option_long_put = Option (
            0, 
            expiry,
            strike_price,
            myusd_addr,
            myeth_addr,
            1,
        );

        let option_short_put = Option (
            1, 
            expiry,
            strike_price,
            myusd_addr,
            myeth_addr,
            1,
        );

        let (
            total_premia_before_fees_long_call,
            total_premia_including_fees_long_call
        ) = IAMM.get_total_premia(
            amm_addr,
            option_long_call,
            lpt_call_addr,
            one,
            0
        );

        let (
            total_premia_before_fees_short_call,
            total_premia_including_fees_short_call
        ) = IAMM.get_total_premia(
            amm_addr,
            option_short_call,
            lpt_call_addr,
            one,
            0
        );
    
        let (
            total_premia_before_fees_long_put,
            total_premia_including_fees_long_put
        ) = IAMM.get_total_premia(
            amm_addr,
            option_long_put,
            lpt_put_addr,
            one,
            0
        );

        let (
            total_premia_before_fees_short_put,
            total_premia_including_fees_short_put
        ) = IAMM.get_total_premia(
            amm_addr,
            option_short_put,
            lpt_put_addr,
            one,
            0
        );

        // Results copied from long/short_put/call round trips (same option size, maturity, strike etc)
        assert total_premia_before_fees_long_call = 2020558154346487;
        assert total_premia_including_fees_long_call = 2081174898976881;

        assert total_premia_before_fees_short_call = 627445539966218;
        assert total_premia_including_fees_short_call = 608622173767232;
        
        assert total_premia_before_fees_long_put = 234655350073966452800;
        assert total_premia_including_fees_long_put = 241695010576185446327;

        assert total_premia_before_fees_short_put = 231276759164374043900;
        assert total_premia_including_fees_short_put = 224338456389442822640;

        return();
    }

    // FIXME: add all of the simple view functions that need setup
}
