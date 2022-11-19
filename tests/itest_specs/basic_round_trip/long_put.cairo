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
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq


namespace LongPutRoundTrip {
    func minimal_round_trip_put{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        // test
        // -> buy put option
        // -> withdraw half of the liquidity that was originally deposited from put pool
        // -> close half of the bought option
        // -> settle pool
        // -> settle the option
        alloc_locals;

        local lpt_call_addr;
        local lpt_put_addr;
        local amm_addr;
        local myusd_addr;
        local myeth_addr;
        local admin_addr;
        local expiry;
        local opt_long_put_addr;
        local opt_short_put_addr;
        local opt_long_call_addr;
        local opt_short_call_addr;

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
        local tmp_address = EMPIRIC_ORACLE_ADDRESS;
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
        let (bal_opt_long_put_tokens_0: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_put_addr,
            account=admin_addr
        );
        assert bal_opt_long_put_tokens_0.low = 0;

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
        let (opt_long_put_position_0) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_0 = 0;
        let (opt_short_put_position_0) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_0 = 0;
        let (opt_long_call_position_0) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_0 = 0;
        let (opt_short_call_position_0) = ILiquidityPool.get_pools_option_position(
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
        assert_uint256_eq(call_pool_balance_0, Uint256(5000000000000000000, 0));
        let (put_pool_balance_0) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_balance_0, Uint256(5000000000, 0));

        // Test pool_locked_capital
        let (call_pool_locked_capital_0) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        let ZERO: Uint256 = Uint256(0, 0);
        assert_uint256_eq(call_pool_locked_capital_0, ZERO);
        let (put_pool_locked_capital_0) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_locked_capital_0, ZERO);

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
        // BUY THE PUT OPTION
        ///////////////////////////////////////////////////

        %{ stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) %}

        let strike_price = Math64x61.fromFelt(1500);
        let one = Math64x61.fromFelt(1);

        let (premia: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr
        );

        assert premia = 234655350073966452800; // approx 101.7655361342164 USD...
        // notice difference in comparison to CALL premia... this is caused by different trade volatility
        // which is caused by different relative size of the option size (here 1ETH->1400USD against 5000USD pool)

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
        assert admin_myUSD_balance_1.low = 4895181498;

        // Test unlocked capital in the pools after the option was bought
        let (call_pool_unlocked_capital_1) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_1 = 11529215046068469760;

        let (put_pool_unlocked_capital_1) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        // size of the unlocked pool is 5kUSD (original) - 1ETH(=1500USD -> locked by the trade) + premium + 0.03*premium
        // 0.03 because of 3% fees calculated from premium
        // assert put_pool_unlocked_capital_1 = 8312145542824114278327;

        // Test balance of option tokens in the account after the option was bought
        let (bal_opt_long_put_tokens_0: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_put_addr,
            account=admin_addr
        );
        assert bal_opt_long_put_tokens_0.low = 1000000000000000000;

        // Test pool_volatility -> 142.85714285714286 put and 100 call
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
        assert put_volatility_1 = 329406144173384850100;

        // Test option position
        let (opt_long_put_position_1) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_1 = 0;
        let (opt_short_put_position_1) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_1 = 2305843009213693952;
        let (opt_long_call_position_1) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_1 = 0;
        let (opt_short_call_position_1) = ILiquidityPool.get_pools_option_position(
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
        assert_uint256_eq(call_pool_balance_1, Uint256(5000000000000000000, 0));
        let (put_pool_balance_1) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_balance_1, Uint256(5104818502, 0));

        // Test pool_locked_capital
        let (call_pool_locked_capital_1) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert_uint256_eq(call_pool_locked_capital_1, ZERO);
        let (put_pool_locked_capital_1) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_locked_capital_1, Uint256(3458764513820540928000, 0));

        // Test get_value_of_pool_position
        // Should be 0 since, pool does not have any position
        let (call_pool_value_1) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_value_1 = 0;
        // Paid premia was 234655350073966452800 (101.7655361342164)
        // Pool has locked capital in 1500 usd
        // Value of pool is
        //      locked capital - premia to be paid if a user was closing such position
        // If the pool's position would be close, it would be by BUY -> the option is higher
        // then paid by the user initially
        //      1500 - 104.84861524628764 = 1395.1513847537124 -> 3217000067329152198159
        let (put_pool_value_1) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_value_1 = 3217000067329280248686;

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
        assert admin_myUSD_balance_2.low = 6912915325;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_2 = 11529215046068469760;

        // 3659568103382171319752 translates to 1587.0846752182429 (because 3659568103382171319752 / 2**61)
        // before the withdraw there was 3604.818502218243 of unlocked capital
        // the withdraw meant that 40% of the value of pool was withdrawn
        //      which is 3604.818502218243 of unlocked capital plus remaining capital from short option
        //      where the remaining of short is (locked capital - premia of long option)... adjusted for fees
        //      the value of long was 60.48393471824238 (NOT CHECKED !!! -> JUST BY EYE)
        // So the value of pool was 3604.818502218243 + 1500 - 60.48393471824238 = 5044.3345675
        // Withdrawed 40% -> 2017.733827 from unlocked capital
        // Remaining unlocked capital is 3604.818502218243 - 2017.733827 = 1587.0846752182429
        let (put_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_2 = 3659568102878937471359;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_long_put_tokens_2: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_put_addr,
            account=admin_addr
        );
        assert bal_opt_long_put_tokens_2.low = 1000000000000000000;

        // Test pool_volatility -> 142.85714285714286 put and 100 call
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
        assert put_volatility_2 = 329406144173384850100;

        // Test option position
        let (opt_long_put_position_2) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_2 = 0;
        let (opt_short_put_position_2) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_2 = 2305843009213693952;
        let (opt_long_call_position_2) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_2 = 0;
        let (opt_short_call_position_2) = ILiquidityPool.get_pools_option_position(
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
        assert_uint256_eq(call_pool_balance_2, Uint256(5000000000000000000, 0));
        let (put_pool_balance_2) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_balance_2, Uint256(3087084675, 0));

        // Test pool_locked_capital
        let (call_pool_locked_capital_2) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert_uint256_eq(call_pool_locked_capital_2, ZERO);
        let (put_pool_locked_capital_2) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_locked_capital_2, Uint256(3458764513820540928000, 0));

        // Test get_value_of_pool_position
        // Should be 0 since, pool does not have any position
        let (call_pool_value_2) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_value_2 = 0;
        // Pool has locked capital in 1500 usd
        // Value of pool is
        //      locked capital - premia to be paid if a user was closing such position
        // If the pool's position would be close, it would be by BUY -> the option is higher
        // then paid by the user initially
        //      1500 - 58.24467754184775 = 1441.7553224585047 -> 3324461431287578330205
        let (put_pool_value_2) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_value_2 = 3324461431287578330205;

        ///////////////////////////////////////////////////
        // CLOSE HALF OF THE BOUGHT OPTION
        ///////////////////////////////////////////////////
        let two = Math64x61.fromFelt(2);
        let half = Math64x61.div(one, two);

        let (premia: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr
        );

        assert premia = 134675785494767915950; // approx 58.40631168584766 USD...

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
        let (admin_myUSD_balance_3: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_3.low = 6941242386;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_3) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_3 = 11529215046068469760;

        // 5323632604327120150274 translates to 2308.757614050451 (because 5323632604327120150274 / 2**61)
        // before the close of half of the option there was 1587.118450218243 of unlocked capital
        // At the same time the user has been payd option premia for the closing of the option
        //      (similar to sell since the user was long)
        // The premia is 58.40631168616885 * 0.5 -> 29.203155843084424
        // There is also fee on the premia 29.203155843084424 * 0.03
        // The current unlocked capital is:
        //      previous state + 750 USD - 29.203155843084424 + 0.8760946752925327 = 2308.757614050451
        //      1587.0846752182429 + 750 - 29.203155843084424 + 0.8760946752925327 = 2308.757614050451
        let (put_pool_unlocked_capital_3) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_3 = 5323632604210788064745;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_long_put_tokens_3: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_put_addr,
            account=admin_addr
        );
        assert bal_opt_long_put_tokens_3.low = 500000000000000000;

        // Test pool_volatility -> 142.85714285714286 put and 100 call
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
        assert put_volatility_3 = 329406144173384850100; // close option has no impact on volatility

        // Test option position
        let (opt_long_put_position_3) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_3 = 0;
        let (opt_short_put_position_3) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_3 = 1152921504606846976;
        let (opt_long_call_position_3) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_3 = 0;
        let (opt_short_call_position_3) = ILiquidityPool.get_pools_option_position(
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
        assert_uint256_eq(call_pool_balance_3, Uint256(5000000000000000000, 0));
        let (put_pool_balance_3) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        // Previous state - premia + fee on premia
        // 3087.084675218243 - 29.203155843084424 + 0.8760946752925327 = 3058.757614050451
        assert_uint256_eq(put_pool_balance_3, Uint256(3058757614, 0));

        // Test pool_locked_capital
        let (call_pool_locked_capital_3) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert_uint256_eq(call_pool_locked_capital_3, ZERO);
        let (put_pool_locked_capital_3) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_locked_capital_3,Uint256(1729382256910270464000, 0));

        // Test get_value_of_pool_position
        // Should be 0 since, pool does not have any position
        let (call_pool_value_3) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_value_3 = 0;
        // Pool has locked capital in 1500 usd
        // Value of pool is
        //      locked capital - premia to be paid if a user was closing such position
        // If the pool's position would be close, it would be by BUY -> the option is higher
        // then paid by the user initially
        //      750 - 30.5379048661066 = 719.4620951339164 -> 1658966642458778712853
        let (put_pool_value_3) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_value_3 = 1658966642458778712853;

        ///////////////////////////////////////////////////
        // SETTLE (EXPIRE) POOL
        ///////////////////////////////////////////////////

        %{
            stop_warp_1()
            # Set the time 1 second AFTER expiry
            stop_warp_2 = warp(1000000000 + 60*60*24 + 1, target_contract_address=ids.amm_addr)

            # Mock the terminal price
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [0, 145000000000, 0, 0, 0]  # mock terminal ETH price at 1450
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
        assert admin_myUSD_balance_4.low = 6941242386;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_4) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_4 = 11529215046068469760;

        // 6995368786007048265474 translates to 3033.757614050451
        // Before the settlement there is 2308.757614050451 of unlocked capital and 750 of locked one
        // Calling the expire_option_token_for_pool means that part of the 750 that should stay with the pool
        // is unlocked
        // additional unlocked capital = 750 - profit of the users long * option size = 750 - 50 * 0.5 = 725
        // newly unlocked capital is 2308.757614050451 + 725 = 3033.757614050451
        let (put_pool_unlocked_capital_4) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_4 = 6995368785890716179945;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_long_put_tokens_4: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_put_addr,
            account=admin_addr
        );
        assert bal_opt_long_put_tokens_4.low = 500000000000000000;

        // Test pool_volatility -> 142.85714285714286 put and 100 call
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
        assert put_volatility_4 = 329406144173384850100; // close option has no impact on volatility

        // Test option position
        let (opt_long_put_position_4) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_4 = 0;
        let (opt_short_put_position_4) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_4 = 0;
        let (opt_long_call_position_4) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_4 = 0;
        let (opt_short_call_position_4) = ILiquidityPool.get_pools_option_position(
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
        assert_uint256_eq(call_pool_balance_4, Uint256(5000000000000000000, 0));
        let (put_pool_balance_4) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        // Previous state - what will be payed to the option owner
        // 3058.757614050451 - 25
        assert_uint256_eq(put_pool_balance_4, Uint256(3033757614, 0));

        // Test pool_locked_capital
        let (call_pool_locked_capital_4) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert_uint256_eq(call_pool_locked_capital_4, ZERO);
        let (put_pool_locked_capital_4) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_locked_capital_4, ZERO);

        // Test get_value_of_pool_position
        // Should be 0 since, pool does not have any position
        let (call_pool_value_4) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_value_4 = 0;
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
            option_side=0,
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
        assert admin_myUSD_balance_5.low = 6966242386;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_5) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_5 = 11529215046068469760;

        // At this moment no additional capital is unlocked
        // (that happened when the option was settled for the pool)
        let (put_pool_unlocked_capital_5) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_5 = 6995368785890716179945;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_long_put_tokens_5: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_put_addr,
            account=admin_addr
        );
        assert bal_opt_long_put_tokens_5.low = 0;

        // Test pool_volatility -> 142.85714285714286 put and 100 call
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
        assert put_volatility_5 = 329406144173384850100; // close option has no impact on volatility

        // Test option position
        let (opt_long_put_position_5) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_5 = 0;
        let (opt_short_put_position_5) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_5 = 0;
        let (opt_long_call_position_5) = ILiquidityPool.get_pools_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_5 = 0;
        let (opt_short_call_position_5) = ILiquidityPool.get_pools_option_position(
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
        assert_uint256_eq(call_pool_balance_5, Uint256(5000000000000000000, 0));
        let (put_pool_balance_5) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_balance_5, Uint256(3033757614, 0));

        // Test pool_locked_capital
        let (call_pool_locked_capital_5) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert_uint256_eq(call_pool_locked_capital_5, ZERO);
        let (put_pool_locked_capital_5) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert_uint256_eq(put_pool_locked_capital_5, ZERO);

        // Test get_value_of_pool_position
        // Should be 0 since, pool does not have any position
        let (call_pool_value_5) = ILiquidityPool.get_value_of_pool_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_value_5 = 0;
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
