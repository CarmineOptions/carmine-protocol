%lang starknet

from contracts.interfaces.interface_amm import IAMM
from contracts.interfaces.interface_lptoken import ILPToken
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from types import Math64x61_
from openzeppelin.token.erc20.IERC20 import IERC20
from constants import EMPIRIC_ORACLE_ADDRESS
from tests.itest_specs.itest_utils import Stats, StatsInput, print_stats, get_stats

from math64x61 import Math64x61


namespace SeriesOfTrades {
    func trade_open{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;

        // 12 hours after listing, 12 hours before expir
        %{ warp(1000000000 + 60*60*12, target_contract_address = context.amm_addr) %}

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        
        tempvar opt_long_call_addr;
        tempvar opt_short_call_addr;
        tempvar opt_long_put_addr;
        tempvar opt_short_put_addr;
        
        tempvar amm_addr;
        
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;

        tempvar expiry;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr

            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_call_addr = context.opt_short_call_addr_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0
            
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address

            ids.expiry = context.expiry_0
        %}

        let strike_price = Math64x61.fromFelt(1500);
        let one_option_size = 1 * 10**18;

        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_spot_checkpoint_before", [145000000000, 0, 0, 0, 0]  # mock terminal ETH price at 1450
            )
        %}

        // First trade, LONG CALL
        let (premia_long_call: Math64x61_) = IAMM.trade_open(
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

        assert premia_long_call = 1803246998050415; // approx 0.00087 ETH, or 1.22 USD

        // Second trade, SHORT CALL
        let (premia_short_call: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=1, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );

        assert premia_short_call = 1803246998050415; // approx the same as before, but slightly higher, since vol. was increased 
                                                     // with previous trade
        // Second trade, PUT LONG
        let (premia_long_put: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=230584300921369395200000, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );

        assert premia_long_put = 233736537374646457500;

        // Second trade, PUT SHORT
        let (premia_short_put: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=one_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=1, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );

        assert premia_short_put = 233736537374646457500; 

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

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_0.low = 3493917976;

        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_0.low = 3999953077976492459;

        let (stats_long_put_0) = get_stats(long_put_input);
        let (stats_short_put_0) = get_stats(short_put_input);
        let (stats_short_call_0) = get_stats(short_call_input);
        let (stats_long_call_0) = get_stats(long_call_input);

        // Assert amount of unlocked capital
        assert stats_long_put_0.pool_unlocked_capital = 5006082024;
        assert stats_long_call_0.pool_unlocked_capital = 5000046922023507541;

        // Assert position from pool's position
        assert stats_long_put_0.opt_long_pos = 0;
        assert stats_long_put_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_long_pos = 0;

        // Assert lpool balance
        assert stats_long_put_0.lpool_balance = 5006082024;
        assert stats_long_call_0.lpool_balance = 5000046922023507541;

        // Assert locked capital
        assert stats_long_put_0.pool_locked_capital = 0;
        assert stats_long_call_0.pool_locked_capital = 0;

        // Assert pool position value
        assert stats_long_put_0.pool_position_val = 0;
        assert stats_long_call_0.pool_position_val = 0;
        
        
        
        %{
            # optional, but included for completeness and extensibility
            stop_prank_amm()
            stop_mock_current_price()
            stop_mock_terminal_price()
        %}
        return ();
    }

    func trade_close{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {

        additional_setup(); //conducts some trades
        close_trade_part(); // closes half of the position
        close_trade_rest(); // closes rest of the position
        close_trade_not_enough_opt(); // Tries to close more but there is not enough opt
        // The last test ends with expect_revert cheatcode,
        // so it has to be last since there can't be any other code executed after that
                    
        return ();
    }
    

    func close_trade_part{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;

        // 12 hours after listing, 12 hours before expir
        %{ warp(1000000000 + 60*60*12, target_contract_address = context.amm_addr) %}

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;

        tempvar opt_long_call_addr;
        tempvar opt_short_call_addr;
        tempvar opt_long_put_addr;
        tempvar opt_short_put_addr;
        
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;

        tempvar expiry;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            
            ids.opt_short_call_addr = context.opt_short_call_addr_0
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address

            ids.expiry = context.expiry_0
        %}

        let strike_price = Math64x61.fromFelt(1500);
        // let one = Math64x61.fromFelt(1);
        let one = 1000000000000000000;
        let two = Math64x61.fromFelt(2);
        // let half = Math64x61.div(one, two);
        let half = 500000000000000000;

        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [145000000000, 0, 0, 0, 0]  # mock terminal ETH price at 1450
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

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_0.low = 3493917976;
        
        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_0.low = 3999953077976492459;

        let (stats_long_put_0) = get_stats(long_put_input);
        let (stats_short_put_0) = get_stats(short_put_input);
        let (stats_short_call_0) = get_stats(short_call_input);
        let (stats_long_call_0) = get_stats(long_call_input);

        // Assert amount of unlocked capital
        assert stats_long_put_0.pool_unlocked_capital = 5006082024;
        assert stats_long_call_0.pool_unlocked_capital = 5000046922023507541;

        // Assert position from pool's position
        assert stats_long_put_0.opt_long_pos = 0;
        assert stats_long_put_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_long_pos = 0;

        // Assert lpool balance
        assert stats_long_put_0.lpool_balance = 5006082024;
        assert stats_long_call_0.lpool_balance = 5000046922023507541;

        // Assert locked capital
        assert stats_long_put_0.pool_locked_capital = 0;
        assert stats_long_call_0.pool_locked_capital = 0;

        // Assert pool position value
        assert stats_long_put_0.pool_position_val = 0;
        assert stats_long_call_0.pool_position_val = 0;

        // CLOSE LONG CALL
        let (premia_long_call: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=1, // Disable check
            tx_deadline=99999999999, // Disable deadline
        );
        // Trade vol: 220113227455893980020
        assert premia_long_call = 787619720418846;

        // CLOSE SHORT CALL
        let (premia_short_call: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=231637759399569650000, // disable check
            tx_deadline=99999999999, // disable deadline
        );
        // Trade vol: 243405858336444144510
        assert premia_short_call = 787619720418846;

        // CLOSE LONG PUT
        let (premia_long_put: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=1, // Disable check
            tx_deadline=99999999999, // Disable deadline
        );
        // Trade vol: 217459010687231486534
        assert premia_long_put = 231515786455444942600;

        // CLOSE SHORT PUT
        let (premia_short_put: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=231637759399569650000, // Disable check
            tx_deadline=99999999999, // Disable deadline
        );
        // Trade vol: 253346179028642670832
        assert premia_short_put = 231515786455444942600;
        
        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_1: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_1.low = 4240905857;
        
        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_1: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_1.low = 4499942830708348813;

        let (stats_long_put_1) = get_stats(long_put_input);
        let (stats_short_put_1) = get_stats(short_put_input);
        let (stats_short_call_1) = get_stats(short_call_input);
        let (stats_long_call_1) = get_stats(long_call_input);

        // Assert amount of unlocked capital
        assert stats_long_put_1.pool_unlocked_capital = 5009094143;
        assert stats_long_call_1.pool_unlocked_capital = 5000057169291651187;

        // Assert position from pool's position
        assert stats_long_put_1.opt_long_pos = 0;
        assert stats_long_put_1.opt_short_pos = 0;
        assert stats_long_call_1.opt_short_pos = 0;
        assert stats_long_call_1.opt_long_pos = 0;

        // Assert lpool balance
        assert stats_long_put_1.lpool_balance = 5009094143;
        assert stats_long_call_1.lpool_balance = 5000057169291651187;

        // Assert locked capital
        assert stats_long_put_1.pool_locked_capital = 0;
        assert stats_long_call_1.pool_locked_capital = 0;

        // Assert pool position value
        assert stats_long_put_1.pool_position_val = 0;
        assert stats_long_call_1.pool_position_val = 0;

        %{
            stop_prank_amm()
            stop_mock_current_price()
            stop_mock_terminal_price()
        %}
        return ();
    }
    
    func close_trade_rest{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;

        // 12 hours after listing, 12 hours before expir
        %{ warp(1000000000 + 60*60*12, target_contract_address = context.amm_addr) %}

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;

        tempvar opt_long_call_addr;
        tempvar opt_short_call_addr;
        tempvar opt_long_put_addr;
        tempvar opt_short_put_addr;
        
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;

        tempvar expiry;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            
            ids.opt_short_call_addr = context.opt_short_call_addr_0
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address

            ids.expiry = context.expiry_0
        %}

        let strike_price = Math64x61.fromFelt(1500);
        let one = Math64x61.fromFelt(1);
        let two = Math64x61.fromFelt(2);
        // let half = Math64x61.div(one, two);
        let half = 500000000000000000;

        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [145000000000, 0, 0, 0, 0]  # mock terminal ETH price at 1450
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

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_0.low = 4240905857;

        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_0.low = 4499942830708348813;

        let (stats_long_put_0) = get_stats(long_put_input);
        let (stats_short_put_0) = get_stats(short_put_input);
        let (stats_short_call_0) = get_stats(short_call_input);
        let (stats_long_call_0) = get_stats(long_call_input);

        // print_stats(stats_long_put_0);
        // print_stats(stats_short_put_0);
        // print_stats(stats_short_call_0);
        // print_stats(stats_long_call_0);

        // Assert amount of unlocked capital
        assert stats_long_put_0.pool_unlocked_capital = 5009094143;
        assert stats_long_call_0.pool_unlocked_capital = 5000057169291651187;

        // Assert position from pool's position
        assert stats_long_put_0.opt_long_pos = 0;
        assert stats_long_put_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_long_pos = 0;

        // Assert lpool balance
        assert stats_long_put_0.lpool_balance = 5009094143;
        assert stats_long_call_0.lpool_balance = 5000057169291651187;

        // Assert locked capital
        assert stats_long_put_0.pool_locked_capital = 0;
        assert stats_long_call_0.pool_locked_capital = 0;

        // Assert pool position value
        assert stats_long_put_0.pool_position_val = 0;
        assert stats_long_call_0.pool_position_val = 0;

        // CLOSE LONG CALL
        let (premia_long_call: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=1, // disable check
            tx_deadline=99999999999, // disable deadline
        );
        // Trade vol: 220113227455893980020
        assert premia_long_call = 787619720418846;

        // CLOSE SHORT CALL
        let (premia_short_call: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=231637759399569650000, // disable check
            tx_deadline=99999999999, // disable deadline
        );
        // Trade vol: 243405858336444144510
        assert premia_short_call = 787619720418846;
        
        // CLOSE LONG PUT
        let (premia_long_put: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=1, // disable check
            tx_deadline=99999999999, // disable deadline
        );
        // Trade vol: 217459010687231486534
        assert premia_long_put = 231515786455444942600;

        // CLOSE SHORT PUT
        let (premia_short_put: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=231637759399569650000, // disable check
            tx_deadline=99999999999, // disable deadline
        );
        // Trade vol: 253346179028642670832
        assert premia_short_put = 231515786455444942600;

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_1: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_1.low = 4987893738;
        
        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_1: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_1.low = 4999932583440205167;

        let (stats_long_put_1) = get_stats(long_put_input);
        let (stats_short_put_1) = get_stats(short_put_input);
        let (stats_short_call_1) = get_stats(short_call_input);
        let (stats_long_call_1) = get_stats(long_call_input);

        // Assert amount of unlocked capital
        assert stats_long_put_1.pool_unlocked_capital = 5012106262;
        assert stats_long_call_1.pool_unlocked_capital = 5000067416559794833;

        // Assert position from pool's position
        assert stats_long_put_1.opt_long_pos = 0;
        assert stats_long_put_1.opt_short_pos = 0;
        assert stats_long_call_1.opt_short_pos = 0;
        assert stats_long_call_1.opt_long_pos = 0;

        // Assert lpool balance
        assert stats_long_put_1.lpool_balance = 5012106262;
        assert stats_long_call_1.lpool_balance = 5000067416559794833;

        // Assert locked capital
        assert stats_long_put_1.pool_locked_capital = 0;
        assert stats_long_call_1.pool_locked_capital = 0;

        // Assert pool position value
        assert stats_long_put_1.pool_position_val = 0;
        assert stats_long_call_1.pool_position_val = 0;

        %{
            stop_prank_amm()
            stop_mock_current_price()
            stop_mock_terminal_price()
        %}
        return ();
    }

    func close_trade_not_enough_opt{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;

        // 12 hours after listing, 12 hours before expir
        %{ warp(1000000000 + 60*60*12, target_contract_address = context.amm_addr) %}

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;

        tempvar opt_long_call_addr;
        tempvar opt_short_call_addr;
        tempvar opt_long_put_addr;
        tempvar opt_short_put_addr;
        
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;

        tempvar expiry;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            
            ids.opt_short_call_addr = context.opt_short_call_addr_0
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address

            ids.expiry = context.expiry_0
        %}

        let strike_price = Math64x61.fromFelt(1500);
        let one = Math64x61.fromFelt(1);

        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
        %}

        %{ expect_revert(error_message = 'SafeUint256: subtraction overflow')%} // FIXME: Should we add our own checks here?

        // CLOSE LONG CALL
        let (_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=1, // disable check
            tx_deadline=99999999999, // disable deadline
        );
    
        return ();
    }



    func trade_settle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;

        additional_setup(); //conducts some trades
        trade_settle_before_pool(); // Settles and option before the pool
        expire_options_for_pool(); // expires all the options for pool
        // trade_settle_part(); // settles part of trade
        // trade_settle_all(); // settles all of the trade
        
        return ();
    }

    func trade_settle_before_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;


        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar opt_long_call_addr;
        tempvar opt_short_call_addr;
        tempvar opt_long_put_addr;
        tempvar opt_short_put_addr;
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;

        tempvar expiry;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_call_addr = context.opt_short_call_addr_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0

            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address

            ids.expiry = context.expiry_0
        %}

        let strike_price = Math64x61.fromFelt(1500);
        let one = Math64x61.fromFelt(1);
        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [0 ,145000000000, 0, 0, 0]  # mock terminal ETH price at 1450
            )
        %}

        %{ warp(1000000000 + 60*60*24 + 1, target_contract_address = context.amm_addr) %}
        
        // Settle whole LONG CALL
        IAMM.trade_settle(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr
        );

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

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_0.low = 3493922427;
        
        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_0.low = 3999947508456065619;

        let (stats_long_put_0) = get_stats(long_put_input);
        let (stats_short_put_0) = get_stats(short_put_input);
        let (stats_short_call_0) = get_stats(short_call_input);
        let (stats_long_call_0) = get_stats(long_call_input);
        
        print_stats(stats_long_call_0);
        print_stats(stats_short_call_0);
        print_stats(stats_long_put_0);
        print_stats(stats_short_put_0);
        
        %{
            print(str(ids.admin_myUSD_balance_0.low), str(ids.admin_myETH_balance_0.low))
        %}

        // Assert amount of unlocked capital
        assert stats_long_put_0.pool_unlocked_capital = 5006077574;
        assert stats_long_call_0.pool_unlocked_capital = 5000052491543934382;

        // Assert position from pool's position
        assert stats_long_put_0.opt_long_pos = 0;
        assert stats_long_put_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_long_pos = 0;

        // Assert lpool balance
        assert stats_long_put_0.lpool_balance = 5006077574;
        assert stats_long_call_0.lpool_balance = 5000052491543934382;

        // Assert locked capital
        assert stats_long_put_0.pool_locked_capital = 0;
        assert stats_long_call_0.pool_locked_capital = 0;

        // Assert pool position value
        assert stats_long_put_0.pool_position_val = 0;
        assert stats_long_call_0.pool_position_val = 0;

        %{
            stop_prank_amm()
            stop_mock_current_price()
            stop_mock_terminal_price()
        %}

        return ();
    }

    func trade_settle_part{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;


        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar opt_long_call_addr;
        tempvar opt_short_call_addr;
        tempvar opt_long_put_addr;
        tempvar opt_short_put_addr;
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;

        tempvar expiry;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_call_addr = context.opt_short_call_addr_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0

            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address

            ids.expiry = context.expiry_0
        %}

        let strike_price = Math64x61.fromFelt(1500);
        let one = Math64x61.fromFelt(1);
        let two = Math64x61.fromFelt(2);
        let half = Math64x61.div(one, two);

        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [0 ,145000000000, 0, 0, 0]  # mock terminal ETH price at 1450
            )
        %}

        %{ warp(1000000000 + 60*60*24 + 1, target_contract_address = context.amm_addr) %}
        
        // Settle half of SHORT CALL and PUT
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

        // Test amount of myUSD on option-buyer's account
        let (admin_myUSD_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myUSD_balance_0.low = 3493922427;
        
        // Test amount of myETH on option-buyer's account
        let (admin_myETH_balance_0: Uint256) = IERC20.balanceOf(
            contract_address=myeth_addr,
            account=admin_addr
        );
        assert admin_myETH_balance_0.low = 3999947508456065619;

        let (stats_long_put_0) = get_stats(long_put_input);
        let (stats_short_put_0) = get_stats(short_put_input);
        let (stats_short_call_0) = get_stats(short_call_input);
        let (stats_long_call_0) = get_stats(long_call_input);
        
        print_stats(stats_long_call_0);
        print_stats(stats_short_call_0);
        print_stats(stats_long_put_0);
        print_stats(stats_short_put_0);
        
        %{
            print(str(ids.admin_myUSD_balance_0.low), str(ids.admin_myETH_balance_0.low))
        %}

        // Assert amount of unlocked capital
        assert stats_long_put_0.pool_unlocked_capital = 5006077574;
        assert stats_long_call_0.pool_unlocked_capital = 5000052491543934382;

        // Assert position from pool's position
        assert stats_long_put_0.opt_long_pos = 0;
        assert stats_long_put_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_short_pos = 0;
        assert stats_long_call_0.opt_long_pos = 0;

        // Assert lpool balance
        assert stats_long_put_0.lpool_balance = 5006077574;
        assert stats_long_call_0.lpool_balance = 5000052491543934382;

        // Assert locked capital
        assert stats_long_put_0.pool_locked_capital = 0;
        assert stats_long_call_0.pool_locked_capital = 0;

        // Assert pool position value
        assert stats_long_put_0.pool_position_val = 0;
        assert stats_long_call_0.pool_position_val = 0;

        %{
            stop_prank_amm()
            stop_mock_current_price()
            stop_mock_terminal_price()
        %}

        return ();
    }
    
    func expire_options_for_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar opt_long_call_addr;
        tempvar opt_short_call_addr;
        tempvar opt_long_put_addr;
        tempvar opt_short_put_addr;
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;

        tempvar expiry;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_call_addr = context.opt_short_call_addr_0
            ids.opt_long_put_addr = context.opt_long_put_addr_0
            ids.opt_short_put_addr = context.opt_short_put_addr_0

            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address

            ids.expiry = context.expiry_0
        %}

        let strike_price = Math64x61.fromFelt(1500);
        let one = Math64x61.fromFelt(1);
        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [0 ,145000000000, 0, 0, 0]  # mock terminal ETH price at 1450
            )
        %}

        %{ warp(1000000000 + 60*60*24 + 1, target_contract_address = context.amm_addr) %}
        
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
        
        %{
            stop_prank_amm()
            stop_mock_current_price()
            stop_mock_terminal_price()
        %}
    
        return ();
    }
    
    // Conducts some trades. Or should we just call trade_open inside other tests?
    func additional_setup{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;

        %{ warp(1000000000 + 60*60*12, target_contract_address = context.amm_addr) %}

        tempvar lpt_call_addr;
        tempvar opt_long_call_addr;
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;

        tempvar expiry;
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address

            ids.expiry = context.expiry_0
        %}

        let strike_price = Math64x61.fromFelt(1500);
        // let one = Math64x61.fromFelt(1);
        let one = 1000000000000000000; // 1 * 10 **18
        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
            stop_mock_terminal_price = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [145000000000, 0, 0, 0, 0]  # mock terminal ETH price at 1450
            )
        %}
        let (premia_long_call: Math64x61_) = IAMM.trade_open(
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
        let (premia_short_call: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=1, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );
        let (premia_long_put: Math64x61_) = IAMM.trade_open(
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
        let (premia_short_put: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=1,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=1, // 100_000
            tx_deadline=99999999999, // Disable deadline
        );
        %{
            # optional, but included for completeness and extensibility
            stop_prank_amm()
            stop_mock_current_price()
            stop_mock_terminal_price()
        %}
        return ();

    }
}
