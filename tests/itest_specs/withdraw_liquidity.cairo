%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool

from starkware.cairo.common.uint256 import Uint256



namespace WithdrawLiquidity {
    func withdraw_liquidity{syscall_ptr: felt*, range_check_ptr}() {
        // test withdraw half of the liquidity that was originally deposited (from both pools)// scenarios
        // FIXME: add scenarios
            // deposit to pool with no position
            // deposit to pool with both long and short positon (different options)
            // watchout for value of pool and that premia is correctly adjusted for fees (fees in case of deposit increase value of pool)

        alloc_locals;

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;
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
        assert call_pool_unlocked_capital = 11529215046068469760;

        let (put_pool_unlocked_capital) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital = 11529215046068469760000;

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
        assert call_pool_unlocked_capital_after = 5764607523034234880;

        let (put_pool_unlocked_capital_after) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_after = 5764607523034234880000;

        %{
            # optional, but included for completeness and extensibility
            stop_prank_amm()
        %}
        return ();
    }

    func withdraw_liquidity_not_enough_unlocked{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME: TODO
        // scenario what happens when there is not enough unlocked liquidity to be withdrawen
        return ();
    }

    func withdraw_liquidity_not_enough_lptokens{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME: TODO
        // scenario when user is trying to withdraw more than he/she has
        return ();
    }

    func withdraw_liquidity_zero_unlocked{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME: TODO
        // scenario when there is 0 unlocked capital
        return ();
    }

    func withdraw_liquidity_zero_unlocked_and_locked{syscall_ptr: felt*, range_check_ptr}() {
        // FIXME: TODO
        // scenario when there is both 0 of unlocked capital and locked capital
        return ();
    }
}