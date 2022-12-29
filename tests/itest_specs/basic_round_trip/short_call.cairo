%lang starknet

from tests.itest_specs.view_functions.liquidity_pool_basic import LPBasicViewFunctions
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


namespace ShortCallRoundTrip {
    func minimal_round_trip_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        // test
        // -> sell call option
        // -> withdraw half of the liquidity that was originally deposited from call pool
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
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_call_addr = context.opt_short_call_addr_0
        %}

        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [1400000000000000000000, 18, 0, 0]  # mock current ETH price at 1400
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
        assert call_pool_unlocked_capital_0.low = 5000000000000000000;

        let (put_pool_unlocked_capital_0) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_0.low = 5000000000;

        // Test initial balance of option tokens in the account
        let (bal_opt_short_call_tokens_0: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_short_call_addr,
            account=admin_addr
        );
        assert bal_opt_short_call_tokens_0.low = 0;

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
        assert call_pool_balance_0.low = 5000000000000000000;
        
        let (put_pool_balance_0) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_0.low = 5000000000;

        // Test pool_locked_capital
        let (call_pool_locked_capital_0) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_0.low = 0;
        let (put_pool_locked_capital_0) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_0.low = 0;

        // test value of pools position
        let (pools_pos_val_call) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call = 0;
        
        let (pools_pos_val_put) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_put_addr
        );
        assert pools_pos_val_put = 0;

        ///////////////////////////////////////////////////
        // SELL THE CALL OPTION
        ///////////////////////////////////////////////////

        %{ stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) %}

        let one = 1 * 10 ** 18;

        let (premia: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_desired_price=-230584300921369395200000, // 100_000
        );

        assert premia = 627445539966218; // approx 0.00036 ETH which may sound like way too different from the long premia, but the trade_vol here is 91.6

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

        // Test amount of myETH in sellers account
        let (admin_myETH_balance_1: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_1.low = 4000263947793208513;
        // 5 - option_size - fees + premia

        // Test unlocked capital in the pools after the option was bought
        let (call_pool_unlocked_capital_1) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        // size of the unlocked pool is 5ETH (original) - premium + 0.03*premium
        assert call_pool_unlocked_capital_1.low = 4999736052206791487;

        let (put_pool_unlocked_capital_1) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_1.low = 5000000000;

        // Test balance of option tokens in the account after the option was bought
        let (bal_opt_short_call_tokens_1: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_short_call_addr,
            account=admin_addr
        );
        assert bal_opt_short_call_tokens_1.low = 1000000000000000000;

        // Test pool_volatility 
        // Vol of 83.33 for call pool
        let (call_volatility_1) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_1 = 192153584101141162600;

        // Vol of 100 for put pool
        let (put_volatility_1) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_1 = 230584300921369395200;

        // Test option position
        // Long put
        let (opt_long_put_position_1) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_1 = 0;

        // Short Put
        let (opt_short_put_position_1) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_1 = 0;

        // Long Call
        let (opt_long_call_position_1) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_1 = 1000000000000000000;

        // Short Call
        let (opt_short_call_position_1) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_1 = 0;

        // Test lpool_balance
        // Call Pool
        let (call_pool_balance_1) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_1.low = 4999736052206791487;

        // Put Pool
        let (put_pool_balance_1) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_1.low = 5000000000;

        // Test pool_locked_capital
        // Call pool
        let (call_pool_locked_capital_1) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_1.low = 0;

        // Put pool
        let (put_pool_locked_capital_1) = ILiquidityPool.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_1.low = 0;

        // test value of pools position
        let (pools_pos_val_call_2) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call_2 = 703156361662287;
        
        let (pools_pos_val_put_2) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_put_addr
        );
        assert pools_pos_val_put_2 = 0;

        ///////////////////////////////////////////////////
        // UPDATE THE ORACLE PRICE
        ///////////////////////////////////////////////////

        %{
            stop_mock_current_price()
            stop_mock_current_price_2 = mock_call(
                ids.tmp_address, "get_spot_median",  [145000000000, 8, 0, 0] # mock current ETH price at 1450
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

        // Test amount of myETH on option-seller's account
        let (admin_myETH_balance_2: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_2.low = 6001354552389695118;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        // 2998221234969251820 -> 2.998645447610305
        // before the withdraw there was 4.99973 of unlocked capital(  5 - premia + fees)
        // the withdraw mean that 40% of the value of pool was withdrawn
        //      which is 4.99973 plus value of long position in option
        // so the value of pool waas 4.997... + 0.00299 = 5.0028..
        // Withdrawed 40% -> 2.0010906
        // Remaining unlocked is -> 4.99973 - 2.0010906 = 2.9986...
        assert call_pool_unlocked_capital_2.low = 2998645447610304882;

        let (put_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_2.low = 5000000000;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_short_tokens_2: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_short_call_addr,
            account=admin_addr
        );
        assert bal_opt_short_tokens_2.low = 1000000000000000000;
    
        // Test pool_volatility -> still the same
        let (call_volatility_2) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_2 = 192153584101141162600;

        let (put_volatility_2) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_2 = 230584300921369395200;

        // Test option position
        // Long Call
        let (opt_long_call_position_2) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_2 = 1000000000000000000;

        // Short Call
        let (opt_short_call_position_2) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_2 = 0;

        // Long Put
        let (opt_long_put_position_2) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_2 = 0;
        
        // Short Put
        let (opt_short_put_position_2) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_2 = 0;
        
        // Test lpool_balance
        // Call Pool
        let (call_pool_balance_2) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_2.low = 2998645447610304882;

        // Put pool
        let (put_pool_balance_2) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_2.low = 5000000000;
        
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

        // Test unlocked capital
        let (call_pool_unlocked_capital_3) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_2.low = 2998645447610304882;

        let (put_pool_unlocked_capital_2) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_2.low = 5000000000;  

        // test value of pools position
        let (pools_pos_val_call_2) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call_2 = 9180887569361935;
        
        let (pools_pos_val_put_2) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_put_addr
        );
        assert pools_pos_val_put_2 = 0;

        ///////////////////////////////////////////////////
        // CLOSE HALF OF THE BOUGHT OPTION
        ///////////////////////////////////////////////////
        let half = one / 2;

        let (premia_2: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_desired_price=230584300921369395200000, // 100_000
        );

        assert premia_2 = 6665617208432872;

        // Test balance of lp tokens in the account after the option was bought and after withdraw
        let (bal_eth_lpt_3: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt_3.low = 3000000000000000000;

        let (bal_usd_lpt_3: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_3.low = 5000000000;

        // Test amount of myUSD on option-seller's account
        let (admin_myUSD_balance_3: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_3.low = 5000000000;

        // Test amount of myETH on option-seller's account
        let (admin_myETH_balance_3: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_3.low = 6499865815798077144;
        // Previous + 0.5 - premia - fees

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_3) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_3.low = 3000134184201922856;

        let (put_pool_unlocked_capital_3) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_3.low = 5000000000;

        // // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_short_tokens_3: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_short_call_addr,
            account=admin_addr
        );
        assert bal_opt_short_tokens_3.low = 500000000000000000;

        // Test pool_volatility 
        let (call_volatility_3) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_3 = 192153584101141162600; // close option has no impact on volatility

        let (put_volatility_3) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_3 = 230584300921369395200;  

        // Test option position
        let (opt_long_put_position_3) = ILiquidityPool.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_3 = 0;
        
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
        assert opt_long_call_position_3 = 500000000000000000;

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
        assert call_pool_balance_3.low = 3000134184201922856;
        
        let (put_pool_balance_3) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_3.low = 5000000000;

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

        // test value of pools position
        let (pools_pos_val_call_4) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call_4 = 3232316783144058;
        
        let (pools_pos_val_put_4) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_put_addr
        );
        assert pools_pos_val_put_4 = 0;

        // ///////////////////////////////////////////////////
        // // SETTLE (EXPIRE) POOL
        // ///////////////////////////////////////////////////

        %{
            stop_warp_1()
            # Set the time 1 second AFTER expiry
            stop_warp_2 = warp(1000000000 + 60*60*24 + 1, target_contract_address=ids.amm_addr)

            # Mock the terminal price
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [0, 155000000000, 0, 0, 0]  # mock terminal ETH price at 1550
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
        assert bal_eth_lpt_4.low = 3000000000000000000;

        let (bal_usd_lpt_4: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_4.low = 5000000000;

        // Test amount of myUSD on option-seller's account
        let (admin_myUSD_balance_4: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_4.low = 5000000000;

        // Test amount of myETH on option-seller's account
        let (admin_myETH_balance_4: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_4.low = 6499865815798077144;


        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_4) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_4.low = 3016263216459987372;

        let (put_pool_unlocked_capital_4) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_4.low = 5000000000;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_short_call_tokens_4: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_short_call_addr,
            account=admin_addr
        );
        assert bal_opt_short_call_tokens_4.low = 500000000000000000;

        // Test pool_volatility 
        let (call_volatility_4) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_4 = 192153584101141162600;

        let (put_volatility_4) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_4 = 230584300921369395200;

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
        assert call_pool_balance_4.low = 3016263216459987372;

        let (put_pool_balance_4) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_4.low = 5000000000;

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

        // test value of pools position
        let (pools_pos_val_call_5) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call_5 = 0;
        
        let (pools_pos_val_put_5) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_put_addr
        );
        assert pools_pos_val_put_5 = 0;

        ///////////////////////////////////////////////////
        // SETTLE BOUGHT OPTION
        ///////////////////////////////////////////////////
        IAMM.trade_settle(
            contract_address=amm_addr,
            option_type=0,
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
        assert bal_eth_lpt_5.low = 3000000000000000000;

        let (bal_usd_lpt_5: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_5.low = 5000000000;

        // Test amount of myUSD on option-seller's account
        let (admin_myUSD_balance_5: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_5.low = 5000000000;

        // Test amount of myETH on option-seller's account
        let (admin_myETH_balance_5: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        // Seller lost approx. $24.1, due to option expiring ITM, 
        // small diff from 25 is due to recieved premia
        assert admin_myETH_balance_5.low = 6983736783540012627;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_5) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_5.low = 3016263216459987372;

        // At this moment no additional capital is unlocked
        // (that happened when the option was settled for the pool)
        let (put_pool_unlocked_capital_5) = ILiquidityPool.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_5.low = 5000000000;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_long_call_tokens_5: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_call_addr,
            account=admin_addr
        );
        assert bal_opt_long_call_tokens_5.low = 0;

        // Test pool_volatility -> 142.85714285714286 put and 100 call
        let (call_volatility_5) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_5 = 192153584101141162600; // close option has no impact on volatility

        let (put_volatility_5) = ILiquidityPool.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_5 = 230584300921369395200;

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
        assert call_pool_balance_5.low = 3016263216459987372;

        let (put_pool_balance_5) = ILiquidityPool.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_5.low = 5000000000;

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

        // Test value of pools position
        let (pools_pos_val_call_6) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call_6 = 0;
        
        let (pools_pos_val_put_6) = ILiquidityPool.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_put_addr
        );
        assert pools_pos_val_put_6 = 0;

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
