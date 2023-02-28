%lang starknet

from interfaces.interface_lptoken import ILPToken
from interfaces.interface_option_token import IOptionToken
from interfaces.interface_amm import IAMM
from types import Math64x61_
from constants import EMPIRIC_ORACLE_ADDRESS

from openzeppelin.token.erc20.IERC20 import IERC20
from math64x61 import Math64x61

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq

namespace LongCallRoundTrip {
    func minimal_round_trip_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        // test
        // -> buy call option
        // -> withdraw half of the liquidity that was originally deposited from call pool
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
        local opt_long_call_addr;

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

        // Test unlocked capital in the pools
        let (call_pool_unlocked_capital_0) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_0.low = 5000000000000000000;


        let (put_pool_unlocked_capital_0) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );

        assert put_pool_unlocked_capital_0.low = 5000000000;

        // Test initial balance of option tokens in the account
        let (bal_opt_long_call_tokens_0: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_call_addr,
            account=admin_addr
        );
        assert bal_opt_long_call_tokens_0.low = 0;

        // Test pool_volatility -> 100
        let (call_volatility_0) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_0 = 230584300921369395200;

        let (put_volatility_0) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_0 = 230584300921369395200;

        // Test option position from pool's perspective
        let (opt_long_put_position_0) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_0 = 0;
        let (opt_short_put_position_0) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_0 = 0;
        let (opt_long_call_position_0) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_0 = 0;
        let (opt_short_call_position_0) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_0 = 0;

        // Test lpool_balance
        let (call_pool_balance_0) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_0.low = 5000000000000000000;
        
        let (put_pool_balance_0) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_0.low = 5000000000;

        // Test pool_locked_capital
        let (call_pool_locked_capital_0) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_0.low = 0;

        let (put_pool_locked_capital_0) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_0.low = 0;

        // test value of pools position
        let (pools_pos_val_call) = IAMM.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call = 0;
        
        let (pools_pos_val_put) = IAMM.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_put_addr
        );
        assert pools_pos_val_put = 0;

        ///////////////////////////////////////////////////
        // BUY THE CALL OPTION
        ///////////////////////////////////////////////////

        %{ stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) %}

        let strike_price = Math64x61.fromFelt(1500);
        let one_option_size = 1 * 10**18;

        let (premia: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=230584300921369395200000, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );

        let (volatility: Math64x61_) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );

        assert volatility = 288230376151711743900;  // 288230376151711743900 with old m64x61 codebase

        let (unlocked_capital: Uint256) = IAMM.get_unlocked_capital(contract_address=amm_addr, lptoken_address=lpt_call_addr);

        assert unlocked_capital.low = 4000902565738717213; // 9225453211753752689 with old m64x61 codebase which is 4.000902 ETH

        assert premia = 2020558154346487; // approx 0.0006 ETH

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

        // Test amount of myETH in buyers account
        let (admin_myETH_balance_1: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_1.low = 4999097434261282787;
        // Balance left is 4.999378 which is approx:
        //  5 - premia - (premia * 0.03)

        // Test unlocked capital in the pools after the option was bought
        let (call_pool_unlocked_capital_1) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        // size of the unlocked pool is 5ETH (original) - 1ETH (locked by the trade) + premium + 0.03*premium
        // 0.03 because of 3% fees calculated from premium
        assert call_pool_unlocked_capital_1.low = 4000902565738717213;

        let (put_pool_unlocked_capital_1) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_1.low = 5000000000;

        // Test balance of option tokens in the account after the option was bought
        let (bal_opt_long_call_tokens_1: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_call_addr,
            account=admin_addr
        );
        assert bal_opt_long_call_tokens_1.low = 1000000000000000000;

        // Test pool_volatility 
        // Vol of 125.0  for call pool
        let (call_volatility_1) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_1 = 288230376151711743900;

        // Vol of 100 for put pool
        let (put_volatility_1) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_1 = 230584300921369395200;

        // Test option position
        // Long put
        let (opt_long_put_position_1) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_1 = 0;

        // Short Put
        let (opt_short_put_position_1) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_1 = 0;

        // Long Call
        let (opt_long_call_position_1) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_1 = 0;

        // Short Call
        let (opt_short_call_position_1) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_1 = 1000000000000000000; // 1

        // Test lpool_balance
        // Call Pool
        let (call_pool_balance_1) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        call_pool_balance_1.low = 5000902565738717213;

        // Put Pool
        let (put_pool_balance_1) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        put_pool_balance_1.low=5000000000;

        // Test pool_locked_capital
        // Call pool
        let (call_pool_locked_capital_1) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_1.low = 1000000000000000000;

        // Put pool
        let (put_pool_locked_capital_1) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_1.low = 0;
        
        // test value of pools position
        let (pools_pos_val_call_2) = IAMM.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call_2 = 2303761625947164530;
        
        let (pools_pos_val_put_2) = IAMM.get_value_of_pool_position(
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
                ids.tmp_address, "get_spot_median", [145000000000, 8, 0, 0]  # mock current ETH price at 1450
            )
        %}

        ///////////////////////////////////////////////////
        // WITHDRAW CAPITAL - WITHDRAW 40% of lp tokens
        ///////////////////////////////////////////////////
        let two_eth = Uint256(low = 2000000000000000000, high = 0);
        IAMM.withdraw_liquidity(
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

        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_2: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_2.low = 6997406974146663778;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_2) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        // 4617665128964013604 translates to 2.0025930258533364 (because 4617665128964013604 / 2**61)
        // before the withdraw there was 4.000902565738717 of unlocked capital
        // the withdraw meant that 40% of the value of pool was withdrawn
        //      which is 4.000902565738717 of unlocked capital plus remaining capital from short option
        //      where the remaining of short is (locked capital - premia of long option)... adjusted for fees
        //      the value of long was 0.005 (NOT CHECKED !!! -> JUST BY EYE)
        // So the value of pool was 4.000902565738717 + 1 - 0.005128716025264879 = 4.995773849713452
        // Withdrawed 40% -> 1.998309539885381 from unlocked capital
        // Remaining unlocked capital is 4.000902565738717 - 1.998309539885381 = 2.0025930258533364
        assert call_pool_unlocked_capital_2.low = 2002593025853336222;

        let (put_pool_unlocked_capital_2) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_2.low = 5000000000;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_long_call_tokens_2: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_call_addr,
            account=admin_addr
        );
        assert bal_opt_long_call_tokens_2.low = 1000000000000000000;
    
        // Test pool_volatility 
        // Call vol -> 125
        let (call_volatility_2) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_2 = 288230376151711743900;

        // Put vol -> 100
        let (put_volatility_2) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_2 = 230584300921369395200;

        // Test option position
        // Long Call
        let (opt_long_call_position_2) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_2 = 0;

        // Short Call
        let (opt_short_call_position_2) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_2 = 1000000000000000000;

        // Long Put
        let (opt_long_put_position_2) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_2 = 0;
        
        // Short Put
        let (opt_short_put_position_2) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_2 = 0;
        
        // Test lpool_balance
        // Call Pool
        let (call_pool_balance_2) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_2.low = 3002593025853336222;

        // Put pool
        let (put_pool_balance_2) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_2.low = 5000000000;
        
        // Test pool_locked_capital
        let (call_pool_locked_capital_2) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_2.low = 1000000000000000000;

        let (put_pool_locked_capital_2) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_2.low = 0;

        // Test unlocked capital
        let (call_pool_unlocked_capital_2) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_2.low = 2002593025853336222;

        let (put_pool_unlocked_capital_2) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_2.low = 5000000000;

      
        // test value of pools position
        let (pools_pos_val_call_2) = IAMM.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call_2 = 2296093292106925939;
        
        let (pools_pos_val_put_2) = IAMM.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_put_addr
        );
        assert pools_pos_val_put_2 = 0;

        ///////////////////////////////////////////////////
        // CLOSE HALF OF THE BOUGHT OPTION
        ///////////////////////////////////////////////////
        let half = one_option_size / 2;

        let (premia_2: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=-230584300921369395200000, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );

        assert premia_2 = 11484227343495679; // approx 0.0049 ETH or 7.22 USD

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

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_3: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_3.low = 5000000000;

        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_3: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_3.low = 6999822511648280054;

        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_3) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_3.low = 2500177488351719946;

        let (put_pool_unlocked_capital_3) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_3.low = 5000000000;

        // 5765016783309265179 / 2**61 in call pool -> ~2.5 
        // before the close of half the option there was 2.0025930258533364 of unlocked capital
        // // At the same time the user has been payd option premia for the closing of the option
        // //      (similar to sell since the user was long)
        
        // // The premia is 0.00498 * 0.5 -> 0.00249024484702709
        // // There is also fee on the premia 0.00249024484702709 * 0.03

        // // The current unlocked capital is:
        // //   previous state + 0.5 - 0.00249 + 0.00249*0.03 = 2.50017748835172
        // // Note: previous state = 2.0025930258533364

        // // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_long_call_tokens_3: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_call_addr,
            account=admin_addr
        );
        assert bal_opt_long_call_tokens_3.low = 500000000000000000;

        // Test pool_volatility -> 125 call and 100 put
        let (call_volatility_3) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_3 = 288230376151711743900; // close option has no impact on volatility

        let (put_volatility_3) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_3 = 230584300921369395200;  

        // Test option position
        let (opt_long_put_position_3) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_3 = 0;
        
        let (opt_short_put_position_3) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_3 = 0;
        
        let (opt_long_call_position_3) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_3 = 0;

        let (opt_short_call_position_3) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_3 = 500000000000000000;

        // Test lpool_balance
        let (call_pool_balance_3) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_3.low = 3000177488351719946;
        // Previous state - premia + fee on premia
        // 3.0025930258533364 - 0.00249 + 0.00249*0.03 = 3.000177
        
        let (put_pool_balance_3) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_3.low = 5000000000;

        // Test pool_locked_capital
        let (call_pool_locked_capital_3) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_3.low = 500000000000000000;
        
        let (put_pool_locked_capital_3) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_3.low = 0;

        // test value of pools position
        let (pools_pos_val_call_4) = IAMM.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call_4 = 1146740266760908653;
        
        let (pools_pos_val_put_4) = IAMM.get_value_of_pool_position(
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
                ids.tmp_address, "get_last_spot_checkpoint_before", [0, 155000000000, 0, 0, 0]  # mock terminal ETH price at 1550
            )
        %}

        IAMM.expire_option_token_for_pool(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            strike_price=strike_price,
            maturity=expiry,
        );
        IAMM.expire_option_token_for_pool(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            strike_price=strike_price,
            maturity=expiry,
        );
        IAMM.expire_option_token_for_pool(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            strike_price=strike_price,
            maturity=expiry,
        );
        IAMM.expire_option_token_for_pool(
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

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_4: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_4.low = 5000000000;

        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_4: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_4.low = 6999822511648280054;


        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_4) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_4.low = 2984048456093655429;

        // // 6917938287916112155 translates to 
        // Before settlement -> 2.50017748835172 of unlocked, 0.5 of locked
        // After settlement -> 0.5 of locked gets added to unlocked

        let (put_pool_unlocked_capital_4) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_unlocked_capital_4.low = 5000000000;

        // Test balance of option tokens in the account after the option was bought and after withdraw
        let (bal_opt_long_call_tokens_4: Uint256) = IOptionToken.balanceOf(
            contract_address=opt_long_call_addr,
            account=admin_addr
        );
        assert bal_opt_long_call_tokens_4.low = 500000000000000000;

        // Test pool_volatility -> 142.85714285714286 put and 100 call
        let (call_volatility_4) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_4 = 288230376151711743900; // close option has no impact on volatility

        let (put_volatility_4) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_4 = 230584300921369395200; 

        // Test option position
        let (opt_long_put_position_4) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_4 = 0;
        
        let (opt_short_put_position_4) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_4 = 0;
        
        let (opt_long_call_position_4) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_4 = 0;

        let (opt_short_call_position_4) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_4 = 0;

        // Test lpool_balance
        let (call_pool_balance_4) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_4.low = 2984048456093655430;

        let (put_pool_balance_4) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_4.low = 5000000000;

        // Test pool_locked_capital
        let (call_pool_locked_capital_4) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_4.low = 1;

        let (put_pool_locked_capital_4) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_4.low = 0;

        // test value of pools position
        let (pools_pos_val_call_5) = IAMM.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call_5 = 0;
        
        let (pools_pos_val_put_5) = IAMM.get_value_of_pool_position(
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
        assert bal_eth_lpt_5.low = 3000000000000000000;

        let (bal_usd_lpt_5: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_5.low = 5000000000;

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_5: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_5.low = 5000000000;

        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_5: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_5.low = 7015951543906344570;


        // Test unlocked capital in the pools after the option was bought and after withdraw
        let (call_pool_unlocked_capital_5) = IAMM.get_unlocked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_unlocked_capital_5.low = 2984048456093655429;

        // At this moment no additional capital is unlocked
        // (that happened when the option was settled for the pool)
        let (put_pool_unlocked_capital_5) = IAMM.get_unlocked_capital(
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
        let (call_volatility_5) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            maturity=expiry
        );
        assert call_volatility_5 = 288230376151711743900; // close option has no impact on volatility

        let (put_volatility_5) = IAMM.get_pool_volatility(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            maturity=expiry
        );
        assert put_volatility_5 = 230584300921369395200; 

        // Test option position
        let (opt_long_put_position_5) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_put_position_5 = 0;
        
        let (opt_short_put_position_5) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_put_position_5 = 0;
        
        let (opt_long_call_position_5) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_5 = 0;

        let (opt_short_call_position_5) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_5 = 0;

        // Test lpool_balance
        let (call_pool_balance_5) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_balance_5.low = 2984048456093655430;

        let (put_pool_balance_5) = IAMM.get_lpool_balance(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_balance_5.low = 5000000000;

        // Test pool_locked_capital
        let (call_pool_locked_capital_5) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr
        );
        assert call_pool_locked_capital_5.low = 1; //rounding error most probably
        
        let (put_pool_locked_capital_5) = IAMM.get_pool_locked_capital(
            contract_address=amm_addr,
            lptoken_address=lpt_put_addr
        );
        assert put_pool_locked_capital_5.low = 0;

        // test value of pools position
        let (pools_pos_val_call_6) = IAMM.get_value_of_pool_position(
            contract_address = amm_addr,
            lptoken_address = lpt_call_addr
        );
        assert pools_pos_val_call_6 = 0;
        
        let (pools_pos_val_put_6) = IAMM.get_value_of_pool_position(
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
