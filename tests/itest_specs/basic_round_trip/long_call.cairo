%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool
from interface_option_token import IOptionToken
from interface_amm import IAMM
from types import Math64x61_
from constants import EMPIRIC_ORACLE_ADDRESS

from openzeppelin.token.erc20.IERC20 import IERC20
from math64x61 import Math64x61

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256


// FIXME: add the rest of the round trip
// FIXME: add missing checks similar to the long put round trip


namespace LongCallRoundTrip {
    func minimal_round_trip_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        // test
        // -> buy call option
        // -> withdraw half of the liquidity that was originally deposited from call pool
        // FIXME: TBD -> close half of the bought option
        // FIXME: TBD -> settle pool
        // FIXME: TBD -> settle the option
        alloc_locals;

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;
        tempvar expiry;
        tempvar opt_long_call_addr;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address
            ids.expiry = context.expiry_0
            ids.opt_long_call_addr = context.opt_long_call_addr_0
        %}

        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [1400000000000000000000, 18, 0, 0]  # mock current ETH price at 1400
            )
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [0,145000000000, 0, 0, 0]  # mock terminal ETH price at 1450
            )
        %}

        // Test initial balance of lp tokens in the account
        let (bal_eth_lpt_0: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt_0.low = 5000000000000000000;

        let (bal_usd_lpt_0: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_0.low = 5000000000;

        // Test unlocked capital in the pools
        let (call_pool_unlocked_capital_0) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_0 = 11529215046068469760;

        let (put_pool_unlocked_capital_0) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_0 = 11529215046068469760000;

        // Test initial balance of option tokens in the account
        let (bal_opt_long_call_tokens_0: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_call_addr,
            account=admin_addr
        );
        assert bal_opt_long_call_tokens_0.low = 0;

        ///////////////////////////////////////////////////
        // BUY THE CALL OPTION
        ///////////////////////////////////////////////////

        %{ stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) %}

        let strike_price = Math64x61.fromFelt(1500);
        let one = Math64x61.fromFelt(1);

        let (premia: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr
        );

        assert premia = 2020558154346487; // approx 0.0087 ETH

        // Test balance of lp tokens in the account after the option was bought
        let (bal_eth_lpt_1: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt_1.low = 5000000000000000000;

        let (bal_usd_lpt_1: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_1.low = 5000000000;

        // Test unlocked capital in the pools after the option was bought
        let (call_pool_unlocked_capital_1) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        // size of the unlocked pool is 5ETH (original) - 1ETH (locked by the trade) + premium + 0.03*premium
        // 0.03 because of 3% fees calculated from premium
        assert call_pool_unlocked_capital_1 = 9225453211753752689;

        let (put_pool_unlocked_capital_1) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_1 = 11529215046068469760000;

        // Test balance of option tokens in the account after the option was bought
        let (bal_opt_long_call_tokens_1: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_call_addr,
            account=admin_addr
        );
        assert bal_opt_long_call_tokens_1.low = 1000000000000000000;

        ///////////////////////////////////////////////////
        // UPDATE THE ORACLE PRICE
        ///////////////////////////////////////////////////

        %{
            stop_mock_current_price()
            stop_mock_current_price_2 = mock_call(
                ids.tmp_address, "get_spot_median", [1450000000000000000000, 18, 0, 0]  # mock current ETH price at 1450
            )
        %}

        ///////////////////////////////////////////////////
        // WITHDRAW CAPITAL - WITHDRAW 40% of lp tokens
        ///////////////////////////////////////////////////
        let two_eth = Uint256(low = 2000000000000000000, high = 0);
        ILiquidityPool.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myeth_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=0,
            lp_token_amount=two_eth
        );

        // Test balance of lp tokens in the account after the option was bought and after withdraw
        let (bal_eth_lpt_2: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt_2.low = 3000000000000000000;

        let (bal_usd_lpt_2: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_2.low = 5000000000;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        // 4617665128964013607 translates to 2.0025930258533364 (because 4617665128964013607 / 2**61)
        // before the withdraw there was 4.000902565738717 of unlocked capital
        // the withdraw meant that 40% of the value of pool was withdrawn
        //      which is 4.000902565738717 of unlocked capital plus remaining capital from short option
        //      where the remaining of short is (locked capital - premia of long option)... adjusted for fees
        //      the value of long was 0.005 (NOT CHECKED !!! -> JUST BY EYE)
        // So the value of pool was 4.000902565738717 + 1 - 0.005128716025264879 = 4.995773849713452
        // Withdrawed 40% -> 1.998309539885381 from unlocked capital
        // Remaining unlocked capital is 4.000902565738717 - 1.998309539885381 = 2.0025930258533364
        assert call_pool_unlocked_capital_2 = 4617665128964013607;

        let (put_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_2 = 11529215046068469760000;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_long_call_tokens_2: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_call_addr,
            account=admin_addr
        );
        assert bal_opt_long_call_tokens_2.low = 1000000000000000000;

        %{
            # optional, but included for completeness and extensibility
            stop_prank_amm()
            stop_mock_current_price_2()
            stop_mock_terminal_price()
            stop_warp_1()
        %}
        return ();
    }
}
