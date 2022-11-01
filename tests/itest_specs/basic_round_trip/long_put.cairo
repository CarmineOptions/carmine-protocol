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


namespace LongPutRoundTrip {
    func minimal_round_trip_put{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        // test
        // -> buy put option
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

        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_oracle_1 = mock_call(
                ids.EMPIRIC_ORACLE_ADDRESS, "get_value", [1400000000000000000000, 18, 0, 0]  # mock current ETH price at 1400
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
        assert call_pool_balance_0=11529215046068469760;
        let (put_pool_balance_0) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_0=11529215046068469760000;

        // Test pool_locked_capital
        let (call_pool_locked_capital_0) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_0=0;
        let (put_pool_locked_capital_0) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_0=0;

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
        assert put_pool_unlocked_capital_1 = 8312145542824114278327;

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
        assert call_pool_balance_1=11529215046068469760;
        let (put_pool_balance_1) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_1=11770910056644655206327;

        // Test pool_locked_capital
        let (call_pool_locked_capital_1) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_1=0;
        let (put_pool_locked_capital_1) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_1=3458764513820540928000;

        ///////////////////////////////////////////////////
        // UPDATE THE ORACLE PRICE
        ///////////////////////////////////////////////////

        %{
            stop_mock_oracle_1()
            stop_mock_oracle_2 = mock_call(
                ids.EMPIRIC_ORACLE_ADDRESS, "get_value", [1450000000000000000000, 18, 0, 0]  # mock current ETH price at 1450
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
        assert admin_myUSD_balance_2.low = 6912881550;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_2 = 11529215046068469760;

        // 3658935441669791923833 translates to 1586.8103019370387 (because 3658935441669791923833 / 2**61)
        // before the withdraw there was 3604.685906937039 of unlocked capital
        // the withdraw meant that 40% of the value of pool was withdrawn
        //      which is 3604.685906937039 of unlocked capital plus remaining capital from short option
        //      where the remaining of short is (locked capital - premia of long option)... adjusted for fees
        //      the value of long was 40.00310556296108 (NOT CHECKED !!! -> JUST BY EYE)
        // So the value of pool was 3604.685906937039 + 1400 - 40.00310556296108 = 5044.6890125
        // Withdrawed 40% -> 2017.875605 from unlocked capital
        // Remaining unlocked capital is 3604.685906937039 - 2017.875605 = 1586.810301937039
        let (put_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_2 = 3659645983229807512265;

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
        assert call_pool_balance_2=11529215046068469760;
        let (put_pool_balance_2) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_2=7118410497050348440265;

        // Test pool_locked_capital
        let (call_pool_locked_capital_2) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_2=0;
        let (put_pool_locked_capital_2) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_2=3458764513820540928000;

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

        assert premia = 134872855467553216750; // approx 58.491777162897854 USD...

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
        assert admin_myUSD_balance_3.low = 6941250061;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_3) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_3 = 11529215046068469760;

        // 5323614905238314666124 translates to 2308.7499382942374 (because 5323614905238314666124 / 2**61)
        // before the close of half of the option there was 1587.118450218243 of unlocked capital
        // At the same time the user has been payd option premia for the closing of the option
        //      (similar to sell since the user was long)
        // The premia is 58.491777162897854 * 0.5 -> 29.245888581448927
        // There is also fee on the premia 29.245888581448927 * 0.03
        // The current unlocked capital is:
        //      previous state + 750 USD - 29.245888581448927 + 0.8773766574434678 = 2308.749938294238
        let (put_pool_unlocked_capital_3) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_3 = 5323614905238314666124;

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
        assert call_pool_balance_3=11529215046068469760;
        let (put_pool_balance_3) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        // Previous state - premia + fee on premia
        // 3087.1184502182427 - 29.245888581448927 + 0.8773766574434678 = 3058.7499382942374
        assert put_pool_balance_3=7052997162148585130124;

        // Test pool_locked_capital
        let (call_pool_locked_capital_3) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_3=0;
        let (put_pool_locked_capital_3) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_3=1729382256910270464000;

        ///////////////////////////////////////////////////
        // SETTLE (EXPIRE) POOL
        ///////////////////////////////////////////////////

        %{
            stop_warp_1()
            # Set the time 1 second AFTER expiry
            stop_warp_2 = warp(1000000000 + 60*60*24 + 1, target_contract_address=ids.amm_addr)
            # Mock the terminal price
            # FIXME: correctly mock the get_terminal_price -> it has to be done similarly to empiric_median_price
            # by mocking the IEmpiricOracle.get_value... do this once the get_terminal_price is finished
            # stop_mock_terminal = mock_call(
            #     ids.amm_addr, "get_terminal_price", 1450 * 2**61  # mock current ETH price at 1400
            # )
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
        assert admin_myUSD_balance_4.low = 6941250061;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_4) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_4 = 11529215046068469760;

        // 6995351086918242781324 translates to 3033.7499382942374
        // Before the settlement there is 2308.7499382942374 of unlocked capital and 750 of locked one
        // Calling the expire_option_token_for_pool means that part of the 750 that should stay with the pool
        // is unlocked
        // additional unlocked capital = 750 - profit of the users long * option size = 750 - 50 * 0.5 = 725
        // newly unlocked capital is 2308.7499382942374 + 725 = 3033.7499382942374
        let (put_pool_unlocked_capital_4) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_4 = 6995351086918242781324;

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
        assert call_pool_balance_4 = 11529215046068469760;
        let (put_pool_balance_4) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        // Previous state - what will be payed to the option owner
        // 3058.7499382942374 - 25
        assert put_pool_balance_4 = 6995351086918242781324;

        // Test pool_locked_capital
        let (call_pool_locked_capital_4) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_4 = 0;
        let (put_pool_locked_capital_4) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_4 = 0;

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
        assert admin_myUSD_balance_5.low = 6966250061;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_5) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_5 = 11529215046068469760;

        // 6995351086918242781324 translates to 3033.7499382942374
        // Before the settlement there is 2308.7499382942374 of unlocked capital and 750 of locked one
        // Calling the expire_option_token_for_pool means that part of the 750 that should stay with the pool
        // is unlocked
        // additional unlocked capital = 750 - profit of the users long * option size = 750 - 50 * 0.5 = 725
        // newly unlocked capital is 2308.7499382942374 + 725 = 3033.7499382942374
        let (put_pool_unlocked_capital_5) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_5 = 6995351086918242781324;

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
        assert call_pool_balance_5 = 11529215046068469760;
        let (put_pool_balance_5) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_5 = 6995351086918242781324;

        // Test pool_locked_capital
        let (call_pool_locked_capital_5) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_5 = 0;
        let (put_pool_locked_capital_5) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_5 = 0;

        %{

            # optional, but included for completeness and extensibility
            stop_prank_amm()
            stop_warp_2()
            stop_mock_oracle_2()
        %}

        return ();
    }
}
