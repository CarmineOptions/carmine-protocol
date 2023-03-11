%lang starknet

from constants import EMPIRIC_ORACLE_ADDRESS
from starkware.cairo.common.cairo_builtins import HashBuiltin
from tests.itest_specs.itest_utils import Stats, StatsInput, get_stats, print_stats
from starkware.cairo.common.uint256 import Uint256
from openzeppelin.token.erc20.IERC20 import IERC20
from interfaces.interface_lptoken import ILPToken
from interfaces.interface_option_token import IOptionToken
from interfaces.interface_amm import IAMM
from math64x61 import Math64x61

namespace DepositLiquidity {
    func test_deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
       // scenarios
            // deposit to pool with no position
            // deposit to pool with both long and short positon (different options)
            // watchout for value of pool and that premia is correctly adjusted for fees 
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
        // Define inputs for get_stats function
        let long_put_input = StatsInput (
            user_addr = admin_addr,
            lpt_addr = lpt_put_addr,
            amm_addr = amm_addr,
            opt_addr = opt_long_put_addr,
            expiry = expiry,
            strike_price = strike_price
        );
        let short_put_input = StatsInput (
            user_addr = admin_addr,
            lpt_addr = lpt_put_addr,
            amm_addr = amm_addr,
            opt_addr = opt_short_put_addr,
            expiry = expiry,
            strike_price = strike_price
        );
        let long_call_input = StatsInput (
            user_addr = admin_addr,
            lpt_addr = lpt_call_addr,
            amm_addr = amm_addr,
            opt_addr = opt_long_call_addr,
            expiry = expiry,
            strike_price = strike_price
        );
        let short_call_input = StatsInput (
            user_addr = admin_addr,
            lpt_addr = lpt_call_addr,
            amm_addr = amm_addr,
            opt_addr = opt_short_call_addr,
            expiry = expiry,
            strike_price = strike_price
        );

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
        
        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_0.low = 5000000000000000000;

        let (stats_long_put_0) = get_stats(long_put_input);
        let (stats_short_put_0) = get_stats(short_put_input);
        let (stats_short_call_0) = get_stats(short_call_input);
        let (stats_long_call_0) = get_stats(long_call_input);

        // Assert initial amount of unlocked capital
        assert stats_long_put_0.pool_unlocked_capital = 5000000000;
        assert stats_long_call_0.pool_unlocked_capital = 5000000000000000000;
        
        // Assert initial volatility
        assert stats_long_put_0.pool_volatility = 230584300921369395200; // 1
        assert stats_long_call_0.pool_volatility = 230584300921369395200; // 1

        // Assert inital position from pool's position
        assert stats_long_put_0.opt_long_pos = 0;
        assert stats_long_put_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_long_pos = 0;

        // Assert initial lpool balance
        assert stats_long_put_0.lpool_balance = 5000000000;
        assert stats_long_call_0.lpool_balance = 5000000000000000000;

        // Assert initial locked capital
        assert stats_long_put_0.pool_locked_capital = 0;
        assert stats_long_call_0.pool_locked_capital = 0;

        // Assert initial pool position value
        assert stats_long_put_0.pool_position_val = 0;
        assert stats_long_call_0.pool_position_val = 0;

        ///////////////////////////////////////////////////
        // DEPOSIT MORE LIQUIDITY
        ///////////////////////////////////////////////////
        // Deposit one more eth and one thousand more usd
        let one_eth = Uint256(low = 1000000000000000000, high = 0);
        let one_thousand_usd = Uint256(low = 1000000000, high = 0);

        IAMM.deposit_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myeth_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=0,
            amount=one_eth
        );
        IAMM.deposit_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myusd_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=1,
            amount=one_thousand_usd
        );

        // Test balance of lp tokens in the account
        let (bal_eth_lpt_1: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt_1.low = 6000000000000000000;

        let (bal_usd_lpt_1: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_1.low = 6000000000;

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_1: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_1.low = 4000000000;
        
        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_1: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_1.low = 4000000000000000000;

        let (stats_long_put_1) = get_stats(long_put_input);
        let (stats_short_put_1) = get_stats(short_put_input);
        let (stats_short_call_1) = get_stats(short_call_input);
        let (stats_long_call_1) = get_stats(long_call_input);

        // Assert amount of unlocked capital
        assert stats_long_put_1.pool_unlocked_capital = 6000000000;
        assert stats_long_call_1.pool_unlocked_capital = 6000000000000000000;
        
        // Assert volatility
        assert stats_long_put_1.pool_volatility = 230584300921369395200;
        assert stats_long_call_1.pool_volatility = 230584300921369395200;

        // Assert position from pool's position
        assert stats_long_put_1.opt_long_pos = 0;
        assert stats_long_put_1.opt_short_pos = 0;
        assert stats_long_call_1.opt_short_pos = 0;
        assert stats_long_call_1.opt_long_pos = 0;

        // Assert lpool balance
        assert stats_long_put_1.lpool_balance = 6000000000;
        assert stats_long_call_1.lpool_balance = 6000000000000000000;

        // Assert locked capital
        assert stats_long_put_1.pool_locked_capital = 0;
        assert stats_long_call_1.pool_locked_capital = 0;

        // Assert pool position value
        assert stats_long_put_1.pool_position_val = 0;
        assert stats_long_call_1.pool_position_val = 0;

        
        ///////////////////////////////////////////////////
        // CONDUCT TRADES
        ///////////////////////////////////////////////////

        // First, deploy some additional short options with longer expiry so the pool has position in two different options       
        %{ stop_warp_1 = warp(1000000000, target_contract_address=ids.amm_addr) %}
        tempvar expiry_longer;
        tempvar opt_short_call_addr_2;
        tempvar opt_short_put_addr_2;
        tempvar opt_long_call_addr_2;
        tempvar opt_long_put_addr_2;
        %{
            expiry_longer = int(1000000000 + 60*60*48)
            ids.expiry_longer = expiry_longer

            ids.opt_short_call_addr_2 = deploy_contract(
                "./contracts/erc20_tokens/option_token.cairo",
                [1234, 14, 18, 0, 0, context.admin_address, context.amm_addr, context.myusd_address, context.myeth_address, 0, ids.strike_price, expiry_longer, 1]
            ).contract_address

            ids.opt_short_put_addr_2 = deploy_contract(
                "./contracts/erc20_tokens/option_token.cairo",
                [1234, 14, 18, 0, 0, context.admin_address, context.amm_addr, context.myusd_address, context.myeth_address, 1, ids.strike_price, expiry_longer, 1]
            ).contract_address

            ids.opt_long_call_addr_2 = deploy_contract(
                "./contracts/erc20_tokens/option_token.cairo",
                [1234, 14, 18, 0, 0, context.admin_address, context.amm_addr, context.myusd_address, context.myeth_address, 0, ids.strike_price, expiry_longer, 0]
            ).contract_address

            ids.opt_long_put_addr_2 = deploy_contract(
                "./contracts/erc20_tokens/option_token.cairo",
                [1234, 14, 18, 0, 0, context.admin_address, context.amm_addr, context.myusd_address, context.myeth_address, 1, ids.strike_price, expiry_longer, 0]
            ).contract_address
        
        %}
        let hundred_m64x61 = Math64x61.fromFelt(100);
        // Add short long option with longer maturity
        IAMM.add_option(
            contract_address=amm_addr,
            option_side=1,
            maturity=expiry_longer,
            strike_price=strike_price,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=0,
            lptoken_address=lpt_call_addr,
            option_token_address_=opt_short_call_addr_2,
            initial_volatility=hundred_m64x61
        );
        // Add short put option with longer maturity
        IAMM.add_option(
            contract_address=amm_addr,
            option_side=1,
            maturity=expiry_longer,
            strike_price=strike_price,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=1,
            lptoken_address=lpt_put_addr,
            option_token_address_=opt_short_put_addr_2,
            initial_volatility=hundred_m64x61
        );
        // Add options for other side as well
        IAMM.add_option(
            contract_address=amm_addr,
            option_side=0,
            maturity=expiry_longer,
            strike_price=strike_price,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=0,
            lptoken_address=lpt_call_addr,
            option_token_address_=opt_long_call_addr_2,
            initial_volatility=hundred_m64x61
        );
        // Add short put option with longer maturity
        IAMM.add_option(
            contract_address=amm_addr,
            option_side=0,
            maturity=expiry_longer,
            strike_price=strike_price,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=1,
            lptoken_address=lpt_put_addr,
            option_token_address_=opt_long_put_addr_2,
            initial_volatility=hundred_m64x61
        );
        
        // Create new additional inputs for get_stats function 
        let short_put_input_2 = StatsInput (
            user_addr = admin_addr,
            lpt_addr = lpt_put_addr,
            amm_addr = amm_addr,
            opt_addr = opt_short_put_addr_2,
            expiry = expiry_longer,
            strike_price = strike_price
        );
        let short_call_input_2 = StatsInput (
            user_addr = admin_addr,
            lpt_addr = lpt_call_addr,
            amm_addr = amm_addr,
            opt_addr = opt_short_call_addr_2,
            expiry = expiry_longer,
            strike_price = strike_price
        );

        // Conduct trades
        // let one_math = Math64x61.fromFelt(1);
        let one_int = 1000000000000000000; // 1 * 10**18
        let one_k_math = Math64x61.fromFelt(1000);
        
        let (long_call_premia) = IAMM.trade_open(
            contract_address = amm_addr,
            option_type = 0,
            strike_price = strike_price,
            maturity = expiry,
            option_side = 0,
            option_size = one_int,
            quote_token_address = myusd_addr,
            base_token_address = myeth_addr,
            limit_total_premia=230584300921369395200000, // 100_000
            tx_deadline=99999999999, // Disable deadline
        ); 
        assert long_call_premia = 7766812800888664;
        // 0.00589 ETH, 4.7 USD 
        // Trade vol: 253642731013506334650 -> 110.0
        
        let (short_call_premia) = IAMM.trade_open(
            contract_address = amm_addr,
            option_type = 0,
            strike_price = strike_price,
            maturity = expiry_longer,
            option_side = 1,
            option_size = one_int,
            quote_token_address = myusd_addr,
            base_token_address = myeth_addr,
            limit_total_premia=1, // 
            tx_deadline=99999999999, // Disable deadline
        ); 
        assert short_call_premia = 12419727668189010; 
        // 0.00383 ETH, 7.96 USD
        // Trade vol: 211380046947561167350 -> 91.671482

        let (long_put_premia) = IAMM.trade_open(
            contract_address = amm_addr,
            option_type = 1,
            strike_price = strike_price,
            maturity = expiry,
            option_side = 0,
            option_size = one_int,
            quote_token_address = myusd_addr,
            base_token_address = myeth_addr,
            limit_total_premia=230584300921369395200000, // 100_000
            tx_deadline=99999999999, // Disable deadline
        ); 
        assert long_put_premia = 243220648420250043900;
        // 105.745 USD
        // Trade vol: 269015017741597627700 -> 116.66666666666667
        
        let (short_put_premia) = IAMM.trade_open(
            contract_address = amm_addr,
            option_type = 1,
            strike_price = strike_price,
            maturity = expiry_longer,
            option_side = 1,
            option_size = one_int,
            quote_token_address = myusd_addr,
            base_token_address = myeth_addr,
            limit_total_premia=1, // 100_000
            tx_deadline=99999999999, // Disable deadline
        ); 
        assert short_put_premia = 245166455952635040200;
       // 106.9768 USD 
       // Trade vol: 202275156612549523650 -> 87.72286569566873

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_2: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_2.low = 2494489735;
        // 5000 - 1000 - long_put_premia - long_put_fee + short_put_premia - short_put_fee - 1500(need for short trade)
        
        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_2: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_2.low = 3001755244670628369;
        // 5 - 1 - long_call_premia - long_call_fee + short_call_premia - short_call_fee - 1(needed for short trade)

        let (stats_long_put_2) = get_stats(long_put_input);
        let (stats_short_put_2) = get_stats(short_put_input_2);
        let (stats_short_call_2) = get_stats(short_call_input_2);
        let (stats_long_call_2) = get_stats(long_call_input);

        // Assert amount of unlocked capital
        assert stats_long_put_2.pool_unlocked_capital = 4505510265;
        // 5000 + 1000 - short_put_premia + short_put_fee + long_put_premia + long_put_fee - 1500(locked capital from trade)
        assert stats_long_call_2.pool_unlocked_capital = 4998244755329371631;
        // 5 + 1 - short_call_premia + short_call_fee + long_call_premia + long_call_fee - 1(locked capital from trade)
        
        // Assert volatility
        assert stats_long_put_2.pool_volatility = 299759591197780213700;
        assert stats_short_put_2.pool_volatility = 161409010644958576700;
        assert stats_long_call_2.pool_volatility = 276701161105643274200;
        assert stats_short_call_2.pool_volatility = 184467440737095516200;

        // Assert option position from pool's perspective
        assert stats_long_put_2.opt_long_pos = 0;
        assert stats_long_put_2.opt_short_pos = 1000000000000000000; // 1

        assert stats_long_call_2.opt_long_pos = 0;
        assert stats_long_call_2.opt_short_pos = 1000000000000000000; // 1

        assert stats_short_put_2.opt_long_pos = 1000000000000000000; // 1
        assert stats_short_put_2.opt_short_pos = 0;

        assert stats_short_call_2.opt_long_pos = 1000000000000000000; // 1
        assert stats_short_call_2.opt_short_pos = 0;

        // Assert lpool balance
        assert stats_long_put_2.lpool_balance = 6005510265;
        assert stats_short_put_2.lpool_balance = 6005510265;
        // 6000 - short_put_premia + short_put_fee + long_put_premia + long_put_fee
        assert stats_long_call_2.lpool_balance = 5998244755329371631;
        assert stats_short_call_2.lpool_balance = 5998244755329371631;
        // 6 - short_call_premia + short_call_fee + long_call_premia + long_call_fee

        // Assert locked capital
        assert stats_long_put_2.pool_locked_capital = 1500000000;
        assert stats_short_put_2.pool_locked_capital = 1500000000;
        // Locked capital from trade for put -> size * strike -> 1 * 1500
        assert stats_long_call_2.pool_locked_capital = 1000000000000000000;
        assert stats_short_call_2.pool_locked_capital = 1000000000000000000;
        // Locked capital from trade dor call -> size -> 1

        // Assert pool position value
        assert stats_long_put_2.pool_position_val = 3446058708221739371897;
        assert stats_short_put_2.pool_position_val = 3446058708221739371897;
        // Premia for long position  -> 105.74739221341785
        // Premia for short position -> 108.63992210015874
        // Total put position value:
        //      long_position + short_position
        //      (long_premia - long_fee) + (1500(locked_capital) - short_premia - short_fee)

        assert stats_long_call_2.pool_position_val = 2309890327866921969;
        assert stats_short_call_2.pool_position_val = 2309890327866921969;
        // Premia for long position  -> 0.0060760
        // Premia for short position -> 0.0033679
        // Total put position value:
        //      long_position + short_position
        //      (long_premia - long_fee) + (1(locked_capital) - short_premia - short_fee)

        ///////////////////////////////////////////////////
        // DEPOSIT (EVEN) MORE LIQUIDITY
        ///////////////////////////////////////////////////

        // Deposit one more eth and one thousand more usd
        IAMM.deposit_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myeth_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=0,
            amount=one_eth
        );
        IAMM.deposit_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=myusd_addr,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            option_type=1,
            amount=one_thousand_usd
        );

        // Test balance of lp tokens in the account
        let (bal_eth_lpt_3: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_call_addr,
            account=admin_addr
        );
        assert bal_eth_lpt_3.low = 7000000000000000000;

        let (bal_usd_lpt_3: Uint256) = ILPToken.balanceOf(
            contract_address=lpt_put_addr,
            account=admin_addr
        );
        assert bal_usd_lpt_3.low = 7000000000;

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_3: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_3.low = 1494489735;
        
        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_3: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_3.low = 2001755244670628369;

        let (stats_long_put_3) = get_stats(long_put_input);
        let (stats_short_put_3) = get_stats(short_put_input_2);
        let (stats_short_call_3) = get_stats(short_call_input_2);
        let (stats_long_call_3) = get_stats(long_call_input);

        // Assert amount of unlocked capital 
        // -> plus one in case of CALL, plus 1_000 in case of PUT
        assert stats_long_put_3.pool_unlocked_capital = 5505510265;
        assert stats_long_call_3.pool_unlocked_capital = 5998244755329371631;
        
        assert stats_short_put_3.pool_unlocked_capital = 5505510265;
        assert stats_short_call_3.pool_unlocked_capital = 5998244755329371631;

        // Assert volatility
        assert stats_long_put_3.pool_volatility = 299759591197780213700;
        assert stats_short_put_3.pool_volatility = 161409010644958576700;
        assert stats_long_call_3.pool_volatility = 276701161105643274200;
        assert stats_short_call_3.pool_volatility = 184467440737095516200;

        // Assert position from pool's perspective -> still same
        assert stats_long_put_3.opt_long_pos = 0;
        assert stats_long_put_3.opt_short_pos = 1000000000000000000;

        assert stats_long_call_3.opt_long_pos = 0;
        assert stats_long_call_3.opt_short_pos = 1000000000000000000;

        assert stats_short_put_3.opt_long_pos = 1000000000000000000;
        assert stats_short_put_3.opt_short_pos = 0;

        assert stats_short_call_3.opt_long_pos = 1000000000000000000;
        assert stats_short_call_3.opt_short_pos = 0;

        // Assert lpool balance
        // -> plus one in case of CALL, plus 1_000 in case of PUT
        assert stats_long_put_3.lpool_balance = 7005510265;
        assert stats_short_put_3.lpool_balance = 7005510265;
        assert stats_long_call_3.lpool_balance = 6998244755329371631;
        assert stats_short_call_3.lpool_balance = 6998244755329371631;

        // Assert locked capital -> still same
        assert stats_long_put_3.pool_locked_capital = 1500000000;
        assert stats_short_put_3.pool_locked_capital = 1500000000;
        assert stats_long_call_3.pool_locked_capital = 1000000000000000000;
        assert stats_short_call_3.pool_locked_capital = 1000000000000000000;

        // Assert pool position value
        assert stats_long_put_3.pool_position_val = 3446058708221739371897;
        assert stats_short_put_3.pool_position_val = 3446058708221739371897;

        assert stats_long_call_3.pool_position_val = 2309890327866921969;
        assert stats_short_call_3.pool_position_val = 2309890327866921969;
        
        return ();
    }
}

