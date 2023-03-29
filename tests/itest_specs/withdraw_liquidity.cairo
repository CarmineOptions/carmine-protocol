%lang starknet

from interface_lptoken import ILPToken
from interface_amm import IAMM

from constants import EMPIRIC_ORACLE_ADDRESS
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from math64x61 import Math64x61


namespace WithdrawLiquidity {
    func withdraw_liquidity{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        local lpt_call_addr;
        local lpt_put_addr;
        local amm_addr;
        local myusd_addr;
        local myeth_addr;
        local admin_addr;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address
        %}

        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        %}

        let (bal_eth_lpt: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt.low = 5000000000000000000;

        let (bal_usd_lpt: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt.low = 5000000000;

        let (call_pool_unlocked_capital) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert_uint256_eq(call_pool_unlocked_capital, Uint256(5000000000000000000, 0));

        let (put_pool_unlocked_capital) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_unlocked_capital, Uint256(5000000000, 0));

        let two_and_half_eth = Uint256(low = 2500000000000000000, high = 0);
        IAMM.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myeth_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=0,
            lp_token_amount=two_and_half_eth
        );

        let two_and_half_thousand_usd = Uint256(low = 2500000000, high = 0);
        IAMM.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myusd_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=1,
            lp_token_amount=two_and_half_thousand_usd
        );

        let (bal_eth_lpt_after: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt_after.low = 2500000000000000000;

        let (bal_usd_lpt_after: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_after.low = 2500000000;

        let (call_pool_unlocked_capital_after) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert_uint256_eq(call_pool_unlocked_capital_after, Uint256(2500000000000000000, 0));

        let (put_pool_unlocked_capital_after) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_unlocked_capital_after, Uint256(2500000000, 0));

        %{
            # optional, but included for completeness and extensibility
            stop_prank_amm()
        %}
        return ();
    }

    func withdraw_liquidity_not_enough_unlocked{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        local lpt_call_addr;
        local lpt_put_addr;
        local amm_addr;
        local myusd_addr;
        local myeth_addr;
        local admin_addr;
        local strike_price;
        local expiry;
        local tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address
            ids.expiry = context.expiry_0

            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
        %}

        let (put_pool_unlocked_capital_0) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        let (call_pool_unlocked_capital_0) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );

        assert call_pool_unlocked_capital_0.low = 5000000000000000000;
        assert put_pool_unlocked_capital_0.low = 5000000000;

        %{ stop_warp_1 = warp(1000000000, target_contract_address=ids.amm_addr) %}
        // let two = Math64x61.fromFelt(2);
        let two = 2000000000000000000; // 2 * 10**18
        let strike_price = Math64x61.fromFelt(1500);

        // Conduct some trades to lock capital
        let (_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=two,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=230584300921369395200000, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );
        let (_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=two,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=230584300921369395200000, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );
        
        let (put_pool_unlocked_capital_1) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        let (call_pool_unlocked_capital_1) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );

        assert call_pool_unlocked_capital_1.low = 3009254392596352226;
        assert put_pool_unlocked_capital_1.low = 2222539723;

        let four_lptokens = Uint256(low = 3000000000000000000, high = 0);
        IAMM.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myeth_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=0,
            lp_token_amount=four_lptokens
        );

        let (call_pool_unlocked_capital_2) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );

        assert call_pool_unlocked_capital_2.low = 9254392596352227;
    
        %{
            expect_revert(error_message = "Not enough 'cash' available funds in pool. Wait for it to be released from locked capital in withdraw_liquidity")
        %}

        let five_thousand_lptokens = Uint256(low = 5000000000, high = 0);
        IAMM.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myusd_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=1,
            lp_token_amount=five_thousand_lptokens
        );

        return ();
    }

    func withdraw_liquidity_not_enough_lptokens_call{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        local amm_addr;
        local myusd_addr;
        local myeth_addr;
        local lpt_call_addr;
        %{
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.lpt_call_addr = context.lpt_call_addr


            expect_revert(error_message = 'ERC20: burn amount exceeds balance')
        %}

        %{
            stop_prank_lpt = start_prank(context.admin_address, context.lpt_call_addr)
        %}
        // Burn some tokens
        let four_lptokens = Uint256(low = 4000000000000000000, high = 0);
        ILPToken.transfer(
            contract_address = lpt_call_addr,
            recipient = 42069,
            amount = four_lptokens
        );

        %{
            stop_prank_lpt()
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        %}

        let two_lptokens = Uint256(low = 2000000000000000000, high = 0);
        IAMM.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myeth_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=0,
            lp_token_amount=two_lptokens
        );
        return ();

    }

    func withdraw_liquidity_not_enough_lptokens_put{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        local amm_addr;
        local myusd_addr;
        local myeth_addr;
        local lpt_put_addr;
        %{
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.lpt_put_addr = context.lpt_put_addr


            expect_revert(error_message = 'ERC20: burn amount exceeds balance')
        %}

        %{
            stop_prank_lpt = start_prank(context.admin_address, context.lpt_put_addr)
        %}
        // Burn some tokens
        let four_thousand_usd = Uint256(low = 4000000000, high = 0);
        ILPToken.transfer(
            contract_address = lpt_put_addr,
            recipient = 42069,
            amount = four_thousand_usd
        );

        %{
            stop_prank_lpt()
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        %}

        let two_thousand_usd = Uint256(low = 2000000000, high = 0);
        IAMM.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myusd_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=1,
            lp_token_amount=two_thousand_usd
        );
        return ();

    }

    func withdraw_liquidity_zero_unlocked{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME: TODO
        // scenario when there is 0 unlocked capital
        // How to have zero unlocked? Trades will always generate at least some fees.
        return ();
    }

    func withdraw_liquidity_zero_unlocked_and_locked{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME: TODO
        // scenario when there is both 0 of unlocked capital and locked capital
        // How to have zero unlocked and locked AND have some lptokens in account?
        return ();
    }
}
