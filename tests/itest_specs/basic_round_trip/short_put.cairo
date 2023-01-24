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


namespace ShortPutRoundTrip {
    func minimal_round_trip_put{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        // test
        // -> sell put option
        // -> withdraw half of the liquidity that was originally deposited from put pool
        // -> close half of the bought option
        // -> settle pool
        // -> settle the option
        alloc_locals;

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;
        tempvar expiry;
        tempvar opt_long_put_addr;
        tempvar opt_short_put_addr;
        tempvar opt_long_call_addr;
        tempvar opt_short_call_addr;

        let strike_price = Math64x61.fromFelt(1500);

        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address
            ids.expiry = context.expiry_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_call_addr = context.opt_short_call_addr_0
        %}
        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
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

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_0.low = 5000000000;

        // Test locked capital in the pools
        let (call_pool_locked_capital_0) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_0.low = 0;
        assert call_pool_locked_capital_0.high = 0;

        // Test lpool balance
        let (call_pool_balance_0) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_0.low = 5 * 10**18;

        // Test unlocked capital in the pools
        let (call_pool_unlocked_capital_0) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_0.low = 5 * 10**18;

        let (put_pool_unlocked_capital_0) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_0.low = 5000000000;

        // Test initial balance of option tokens in the account
        let (bal_opt_short_put_tokens_0: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_short_put_addr,
            account=admin_addr
        );
        assert bal_opt_short_put_tokens_0.low = 0;

        // Test pool_volatility -> 100
        let (call_volatility_0) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_0 = 230584300921369395200;
        let (put_volatility_0) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_0 = 230584300921369395200;

        // Test option position from pool's perspective
        let (opt_long_put_position_0) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_0 = 0;
        let (opt_short_put_position_0) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_0 = 0;
        let (opt_long_call_position_0) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_0 = 0;
        let (opt_short_call_position_0) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_0 = 0;

        // Test lpool_balance
        let (call_pool_balance_0) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_0.low=5000000000000000000;
        let (put_pool_balance_0) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_0.low=5000000000; // 5k usd

        // Test pool_locked_capital
        let (call_pool_locked_capital_0) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_0.low=0;
        let (put_pool_locked_capital_0) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_0.low=0;

        // Test get_value_of_pool_position
        // Should be 0 since, pool does not have any position
        let (call_pool_value_0) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_value_0 = 0;
        let (put_pool_value_0) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_value_0 = 0;

        ///////////////////////////////////////////////////
        // BUY THE SHORT PUT
        ///////////////////////////////////////////////////

        %{ stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) %}

        let decimals_myeth = 18;
        let one = 1 * 10 ** 18;

        let (premia: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr
        );

        assert premia = 231276759164374043900; // approx 100.45491895597071 USD...

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

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_1: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_1.low = 3597291296;

        // Test unlocked capital in the pools after the option was bought
        let (call_pool_unlocked_capital_1) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_1.low = 5000000000000000000;

        let (put_pool_unlocked_capital_1) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        // size of the unlocked pool is 5kUSD (original) - premium + 0.03*premium
        // 0.03 because of 3% fees calculated from premium... and the user is locking capital in
        assert put_pool_unlocked_capital_1.low = 4902708704;

        // Test balance of option tokens in the account after the option was bought
        let (bal_opt_short_put_tokens_1: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_short_put_addr,
            account=admin_addr
        );
        assert bal_opt_short_put_tokens_1.low = 1000000000000000000;

        let (call_volatility_1) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_1 = 230584300921369395200;
        let (put_volatility_1) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_1 = 177372539170284150100;

        // Test option position
        let (opt_long_put_position_1) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_1 = 1000000000000000000;
        let (opt_short_put_position_1) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_1 = 0;
        let (opt_long_call_position_1) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_1 = 0;
        let (opt_short_call_position_1) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_1 = 0;

        // Test lpool_balance
        let (call_pool_balance_1) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_1.low=5000000000000000000;
        let (put_pool_balance_1) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_1.low=4902708704; // 4902 USD

        // Test pool_locked_capital
        let (call_pool_locked_capital_1) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_1.low=0;
        let (put_pool_locked_capital_1) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_1.low=0;

        // Test get_value_of_pool_position
        // Should be 0 since, pool does not have any position
        let (call_pool_value_1) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_value_1 = 0;
        // Paid premia was 231633272615753256900 (100.45 USD)
        // The value of the pool is in terms of "if the position gets sold off how much gets released to the pool"
        // in this case it is just premia as if the pool would sell the option. Which means
        // the premium is smaller than the trade_open premium
        let (put_pool_value_1) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_value_1 = 224659661559513847575; // 97.65 USD

        ///////////////////////////////////////////////////
        // UPDATE THE ORACLE PRICE
        ///////////////////////////////////////////////////

        %{
            stop_mock_current_price()
            stop_mock_current_price_2 = mock_call(
                ids.tmp_address, "get_spot_median", [145000000000, 8, 0, 0]  # mock current ETH price at 1450
            )
        %}

        ///////////////////////////////////////////////////
        // WITHDRAW CAPITAL - WITHDRAW 40% of lp tokens
        ///////////////////////////////////////////////////
        let two_thousand_usd = Uint256(low = 2000000000, high = 0);
        ILiquidityPool.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myusd_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=1,
            lp_token_amount=two_thousand_usd
        );

        // Test balance of lp tokens in the account after the option was bought and after withdraw
        let (bal_eth_lpt_2: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt_2.low = 5000000000000000000;

        let (bal_usd_lpt_2: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_2.low = 3000000000;

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_2: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_2.low = 5579515933;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_2.low = 5000000000000000000;

        // before the withdraw there was 4902.708703284208 of unlocked capital
        // the withdraw meant that 40% of the value of pool was withdrawn
        //      which is 4902.708703284208 of unlocked capital plus value of long position in option
        // So the value of pool was 4902.708703284208 + 52.85288921579195 = 4955.5615925
        // Withdrawed 40% -> 1982.224637 from unlocked capital
        // Remaining unlocked capital is 4902.708703284208 - 1982.224637 = 2920.484066284208
        let (put_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_2.low = 2920484067;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_short_put_tokens_2: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_short_put_addr,
            account=admin_addr
        );
        assert bal_opt_short_put_tokens_2.low = 1000000000000000000;

        let (call_volatility_2) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_2 = 230584300921369395200;
        let (put_volatility_2) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_2 = 177372539170284150100;

        // Test option position
        let (opt_long_put_position_2) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_2 = 1000000000000000000;
        let (opt_short_put_position_2) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_2 = 0;
        let (opt_long_call_position_2) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_2 = 0;
        let (opt_short_call_position_2) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_2 = 0;

        // Test lpool_balance
        let (call_pool_balance_2) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_2.low=5000000000000000000;
        let (put_pool_balance_2) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_2.low=2920484067;

        // Test pool_locked_capital
        let (call_pool_locked_capital_2) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_2.low = 0;
        let (put_pool_locked_capital_2) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_2.low = 0;

        // Test get_value_of_pool_position
        // Should be 0 since, pool does not have any position
        let (call_pool_value_2) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_value_2 = 0;

        // The value of the pool is in terms of "if the position gets sold off how much gets released to the pool"
        // in this case it is just premia as if the pool would sell the option.
        let (put_pool_value_2) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_value_2 = 129768524643053348904;

        ///////////////////////////////////////////////////
        // CLOSE HALF OF THE BOUGHT OPTION
        ///////////////////////////////////////////////////
        let half = one / 2;

        let (premia: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr
        );

        assert premia = 124515225675871019200; // approx 53.9998712746395 USD...

        // Test balance of lp tokens in the account after the option was bought and after withdraw
        let (bal_eth_lpt_3: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt_3.low = 5000000000000000000;

        let (bal_usd_lpt_3: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_3.low = 3000000000;

        // Test amount of myUSD on option-buyer's account
        // 5579515934 (before) + 750 * 10**6 that gets released - premia
        let (admin_myUSD_balance_3: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_3.low = 6301706000;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_3) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_3.low = 5000000000000000000;

        // previous unlocked capital was 6734177767761424787928 and the close of half of the option
        // just adds the premia... 6734177767761424787928 + 27.809934 * 2**61
        let (put_pool_unlocked_capital_3) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_3.low = 2948294000;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_short_put_tokens_3: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_short_put_addr,
            account=admin_addr
        );
        assert bal_opt_short_put_tokens_3.low = 500000000000000000;

        let (call_volatility_3) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_3 = 230584300921369395200;
        let (put_volatility_3) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_3 = 177372539170284150100; // close option has no impact on volatility

        // Test option position
        let (opt_long_put_position_3) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_3 = 500000000000000000;
        let (opt_short_put_position_3) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_3 = 0;
        let (opt_long_call_position_3) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_3 = 0;
        let (opt_short_call_position_3) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_3 = 0;

        // Test lpool_balance
        let (call_pool_balance_3) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_3.low = 5000000000000000000;
        let (put_pool_balance_3) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        // Previous state - premia + fee on premia
        // 2920.4840662842084 + 27.809933706439345 = 2948.293999990648
        // 26.99993563731975
        assert put_pool_balance_3.low = 2948294000;

        // Test pool_locked_capital
        let (call_pool_locked_capital_3) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_3.low = 0;
        let (put_pool_locked_capital_3) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_3.low = 0;

        // Test get_value_of_pool_position
        // Should be 0 since, pool does not have any position
        let (call_pool_value_3) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_value_3 = 0;

        // The value of the pool is in terms of "if the position gets sold off how much gets released to the pool"
        // in this case it is just premia as if the pool would sell the option.
        let (put_pool_value_3) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_value_3 = 60365382251290395849;

        ///////////////////////////////////////////////////
        // SETTLE (EXPIRE) POOL
        ///////////////////////////////////////////////////

        %{
            stop_warp_1()
            # Set the time 1 second AFTER expiry
            stop_warp_2 = warp(1000000000 + 60*60*24 + 1, target_contract_address=ids.amm_addr)

            # Mock the terminal price
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_spot_checkpoint_before", [0, 145000000000, 0, 0, 0]  # mock terminal ETH price at 1450
            )
        %}

        ILiquidityPool.expire_option_token_for_pool(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            strike_price=strike_price,
            maturity=expiry,
        );
        ILiquidityPool.expire_option_token_for_pool(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            strike_price=strike_price,
            maturity=expiry,
        );
        ILiquidityPool.expire_option_token_for_pool(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            strike_price=strike_price,
            maturity=expiry,
        );
        ILiquidityPool.expire_option_token_for_pool(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            strike_price=strike_price,
            maturity=expiry,
        );

        // Test balance of lp tokens in the account after the option was bought and after withdraw
        let (bal_eth_lpt_4: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt_4.low = 5000000000000000000;

        let (bal_usd_lpt_4: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_4.low = 3000000000;

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_4: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_4.low = 6301706000;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_4) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_4.low = 5000000000000000000;

        // previous unlocked capital was 6798303108985114222383 and the expire released
        // some profit from the option (50 * 0.5)
        let (put_pool_unlocked_capital_4) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_4.low = 2973294000;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_short_put_tokens_4: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_short_put_addr,
            account=admin_addr
        );
        assert bal_opt_short_put_tokens_4.low = 500000000000000000;

        let (call_volatility_4) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_4 = 230584300921369395200;
        let (put_volatility_4) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_4 = 177372539170284150100;

        // Test option position
        let (opt_long_put_position_4) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_4 = 0;
        let (opt_short_put_position_4) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_4 = 0;
        let (opt_long_call_position_4) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_4 = 0;
        let (opt_short_call_position_4) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_4 = 0;

        // Test lpool_balance
        let (call_pool_balance_4) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_4.low = 5000000000000000000;
        let (put_pool_balance_4) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_4.low = 2973294000;

        // Test pool_locked_capital
        let (call_pool_locked_capital_4) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_4.low = 0;
        let (put_pool_locked_capital_4) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_4.low = 0;

        // Test get_value_of_pool_position
        // Should be 0 since, pool does not have any position
        let (call_pool_value_4) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_value_4 = 0;

        // Pool has no position at this moment
        let (put_pool_value_4) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_value_4 = 0;

        ///////////////////////////////////////////////////
        // SETTLE BOUGHT OPTION
        ///////////////////////////////////////////////////
        IAMM.trade_settle(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr
        );

        // Test balance of lp tokens in the account after the option was bought and after withdraw
        let (bal_eth_lpt_5: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt_5.low = 5000000000000000000;

        let (bal_usd_lpt_5: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_5.low = 3000000000;

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_5: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_5.low = 7026706000;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_5) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_5.low = 5000000000000000000;
        let (put_pool_unlocked_capital_5) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_5.low = 2973294000;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_short_put_tokens_5: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_short_put_addr,
            account=admin_addr
        );
        assert bal_opt_short_put_tokens_5.low = 0;

        let (call_volatility_5) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_5 = 230584300921369395200;
        let (put_volatility_5) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_5 = 177372539170284150100;

        // Test option position
        let (opt_long_put_position_5) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_5 = 0;
        let (opt_short_put_position_5) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_5 = 0;
        let (opt_long_call_position_5) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_5 = 0;
        let (opt_short_call_position_5) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_5 = 0;

        // Test lpool_balance
        let (call_pool_balance_5) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_5.low = 5000000000000000000;
        let (put_pool_balance_5) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_5.low = 2973294000;

        // Test pool_locked_capital
        let (call_pool_locked_capital_5) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_5.low = 0;
        let (put_pool_locked_capital_5) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_5.low = 0;

        // Test get_value_of_pool_position
        // Should be 0 since, pool does not have any position
        let (call_pool_value_5) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_value_5 = 0;

        // Pool has no position at this moment
        let (put_pool_value_5) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_value_5 = 0;

        %{

            # optional, but included for completeness and extensibility
            stop_prank_amm()
            stop_warp_2()
            stop_mock_current_price_2()
            stop_mock_terminal_price()
        %}

        return ();
    }
}
