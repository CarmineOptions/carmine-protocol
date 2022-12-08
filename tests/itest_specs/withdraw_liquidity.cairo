%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool
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

        let (call_pool_unlocked_capital) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert_uint256_eq(call_pool_unlocked_capital, Uint256(5000000000000000000, 0));

        let (put_pool_unlocked_capital) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_unlocked_capital, Uint256(5000000000, 0));

        let two_and_half_eth = Uint256(low = 2500000000000000000, high = 0);
        ILiquidityPool.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myeth_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=0,
            lp_token_amount=two_and_half_eth
        );

        let two_and_half_thousand_usd = Uint256(low = 2500000000, high = 0);
        ILiquidityPool.withdraw_liquidity(
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

        let (call_pool_unlocked_capital_after) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert_uint256_eq(call_pool_unlocked_capital_after, Uint256(2500000000000000000, 0));

        let (put_pool_unlocked_capital_after) = ILiquidityPool.get_unlocked_capital(
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

        let (put_pool_unlocked_capital_0) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        let (call_pool_unlocked_capital_0) = ILiquidityPool.get_unlocked_capital(
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
            base_token_address=myeth_addr
        );
        let (_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=two,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr
        );
        
        let (put_pool_unlocked_capital_1) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        let (call_pool_unlocked_capital_1) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );

        assert call_pool_unlocked_capital_1.low = 3012715374959942009;
        assert put_pool_unlocked_capital_1.low = 2241738692;

        let four_eth = Uint256(low = 5000000000000000000, high = 0);
        ILiquidityPool.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myeth_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=0,
            lp_token_amount=four_eth
        );

        let (call_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );

        // FIXME: this returns 340282366920938463461387345960256197662 
        // assert call_pool_unlocked_capital_2.low = 3012715374959942009;

        let four_thousand_usd = Uint256(low = 4000000000, high = 0);
        ILiquidityPool.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myusd_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=1,
            lp_token_amount=four_thousand_usd
        );

        let (put_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );

        // FIXME: this returns 340282366920938463463374607430011254584
        // assert put_pool_unlocked_capital_2.low = 3012715374959942009;



        return ();
    }

    func withdraw_liquidity_not_enough_lptokens_call{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        local amm_addr;
        local myusd_addr;
        local myeth_addr;
        %{
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address

            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)

            expect_revert(error_message = 'Failed to transfer token from pool to account in withdraw_liquidity')
        %}

        let six_eth = Uint256(low = 6000000000000000000, high = 0);
        ILiquidityPool.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myeth_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=0,
            lp_token_amount=six_eth
        );
        return ();
    }

    func withdraw_liquidity_not_enough_lptokens_put{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        local amm_addr;
        local myusd_addr;
        local myeth_addr;
        %{
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address

            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)

            expect_revert(error_message = 'Failed to transfer token from pool to account in withdraw_liquidity')
        %}

        let six_thousand_usd = Uint256(low = 6000000000, high = 0);
        ILiquidityPool.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myusd_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=1,
            lp_token_amount=six_thousand_usd
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