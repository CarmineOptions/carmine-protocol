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

namespace ExpireOptionTokenForPool {
    func test_expire_option_token_for_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
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
        // CONDUCT SOME TRADES
        ///////////////////////////////////////////////////

        %{ 
            stop_warp_1 = warp(1000000000, target_contract_address=ids.amm_addr) 
        %}

        let strike_price = Math64x61.fromFelt(1500);
        let one = 1000000000000000000; // 1 * 10**18

        let (premia_put) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=230584300921369395200000, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );
        assert premia_put = 243220648420250043900;

        let (premia_call) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=230584300921369395200000, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );
        assert premia_call = 7766812800888664;
        
        ///////////////////////////////////////////////////
        // JUMP TO FUTURE AND EXPIRE THE POOL
        ///////////////////////////////////////////////////

        %{ 
            stop_mock_current_price()
            stop_warp_1 = warp(1000000000 + 24*60*60 + 1, target_contract_address=ids.amm_addr) 
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
        
        let (stats_long_put_1) = get_stats(long_put_input);
        let (stats_short_put_1) = get_stats(short_put_input);
        let (stats_short_call_1) = get_stats(short_call_input);
        let (stats_long_call_1) = get_stats(long_call_input);

        // Assert amount of unlocked capital
        assert stats_long_put_1.pool_unlocked_capital = 5108644546;
        assert stats_long_call_1.pool_unlocked_capital = 4971211303152419793;
        
        // Assert volatility
        assert stats_long_put_1.pool_volatility = 299759591197780213700; 
        assert stats_long_call_1.pool_volatility = 276701161105643274200; 

        // Assert position from pool's position
        assert stats_long_put_1.opt_long_pos = 0;
        assert stats_long_put_1.opt_short_pos = 0;
        assert stats_long_call_1.opt_short_pos = 0;
        assert stats_long_call_1.opt_long_pos = 0;

        // Assert lpool balance -> same as unlocked now
        // Since puts expired OTM, the capital is -> 5000(previous balance) + premia + premia*0.03 
        assert stats_long_put_1.lpool_balance = 5108644546;
        
        // Calls expired ITM, so the capital is -> 1(previous balance) + premia + premia*0.03 - (50 / 1550) 
        // The 50 is difference between strike and terminal price (payoff for the user)
        assert stats_long_call_1.lpool_balance = 4971211303152419794;

        // Assert locked capital
        assert stats_long_put_1.pool_locked_capital = 0;
        assert stats_long_call_1.pool_locked_capital = 1;

        // Assert pool position value
        assert stats_long_put_1.pool_position_val = 0;
        assert stats_long_call_1.pool_position_val = 0;
        
        ///////////////////////////////////////////////////
        //  TRY TO EXPIRE THE POOL AGAIN
        ///////////////////////////////////////////////////

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

        let (stats_long_put_2) = get_stats(long_put_input);
        let (stats_short_put_2) = get_stats(short_put_input);
        let (stats_short_call_2) = get_stats(short_call_input);
        let (stats_long_call_2) = get_stats(long_call_input);

        // Assert amount of unlocked capital
        assert stats_long_put_2.pool_unlocked_capital = 5108644546;
        assert stats_long_call_2.pool_unlocked_capital = 4971211303152419793;
        
        // Assert volatility
        assert stats_long_put_2.pool_volatility = 299759591197780213700; 
        assert stats_long_call_2.pool_volatility = 276701161105643274200; 

        // Assert position from pool's position
        assert stats_long_put_2.opt_long_pos = 0;
        assert stats_long_put_2.opt_short_pos = 0;
        assert stats_long_call_2.opt_short_pos = 0;
        assert stats_long_call_2.opt_long_pos = 0;

        // Assert lpool balance
        assert stats_long_put_2.lpool_balance = 5108644546;
        assert stats_long_call_2.lpool_balance = 4971211303152419794;

        // Assert locked capital
        assert stats_long_put_2.pool_locked_capital = 0;
        assert stats_long_call_2.pool_locked_capital = 1;

        // Assert pool position value
        assert stats_long_put_2.pool_position_val = 0;
        assert stats_long_call_2.pool_position_val = 0;

        return ();
    }
}
