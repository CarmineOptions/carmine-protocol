%lang starknet

from constants import EMPIRIC_ORACLE_ADDRESS
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from openzeppelin.token.erc20.IERC20 import IERC20
from interfaces.interface_lptoken import ILPToken
from interfaces.interface_option_token import IOptionToken
from interfaces.interface_amm import IAMM
from types import Math64x61_
from math64x61 import Math64x61
from tests.itest_specs.itest_utils import Stats, StatsInput, get_stats

namespace NonEthRoundTrip {
    func additional_setup{syscall_ptr: felt*, range_check_ptr}(){
        alloc_locals;

        tempvar myusd_addr;
        tempvar mybtc_addr;
        tempvar mydoge_addr;
        tempvar admin_addr;
        tempvar amm_addr;
        tempvar lpt_call_addr_btc;
        tempvar lpt_call_addr_doge;
        tempvar opt_long_call_addr_btc;
        tempvar opt_short_call_addr_btc;
        tempvar opt_long_call_addr_doge;
        tempvar opt_short_call_addr_doge;
        
        tempvar expiry;
        tempvar side_long;
        tempvar side_short;
        tempvar optype_call;
        tempvar optype_put;

        let strike_price_btc = Math64x61.fromFelt(20000);
        let strike_price_doge = 230584300921369408; // 0.1 * 2**61
        %{
            admin_address = 123456
            context.lpt_call_addr_doge = deploy_contract("./contracts/erc20_tokens/lptoken.cairo").contract_address
            context.lpt_call_addr_btc = deploy_contract("./contracts/erc20_tokens/lptoken.cairo").contract_address 
            
            # doge has 8 decimals
            # mints 100k myDoge to admin address
            context.mydoge_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [3, 3, 8, 100000 * 10**8, 0, admin_address, admin_address]).contract_address
            # btc has 8 decimals
            # mints 1 myBtc to admin address
            context.mybtc_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [4, 4, 8, 1 * 10**8, 0, admin_address, admin_address]).contract_address
            
            expiry = context.expiry_0
            LONG = 0
            side_long = LONG
            SHORT = 1
            side_short = SHORT
            CALL = 0
            optype_call = CALL
            PUT = 1
            optype_put = PUT
            
            context.opt_long_call_addr_doge = deploy_contract("./contracts/erc20_tokens/option_token.cairo").contract_address
            
            context.opt_short_call_addr_doge = deploy_contract("./contracts/erc20_tokens/option_token.cairo").contract_address
            
            context.opt_long_call_addr_btc = deploy_contract("./contracts/erc20_tokens/option_token.cairo").contract_address

            context.opt_short_call_addr_btc = deploy_contract("./contracts/erc20_tokens/option_token.cairo").contract_address
            
            ids.expiry = expiry
            ids.optype_call = optype_call
            ids.optype_put = optype_put
            ids.side_long = side_long
            ids.side_short = side_short
            
            ids.mybtc_addr = context.mybtc_address
            ids.mydoge_addr = context.mydoge_address   
            ids.myusd_addr = context.myusd_address
            
            ids.amm_addr = context.amm_addr
            ids.admin_addr = admin_address
            
            ids.lpt_call_addr_btc = context.lpt_call_addr_btc
            ids.lpt_call_addr_doge = context.lpt_call_addr_doge
            
            ids.opt_long_call_addr_doge = context.opt_long_call_addr_doge
            ids.opt_short_call_addr_doge = context.opt_short_call_addr_doge
            ids.opt_long_call_addr_btc = context.opt_long_call_addr_btc
            ids.opt_short_call_addr_btc = context.opt_short_call_addr_btc
        %}
        //[112, 12, 18, 0, 0, admin_address, context.amm_addr]
        ILPToken.initializer(contract_address=lpt_call_addr_doge, name=112, symbol=12, proxy_admin=admin_addr, owner=amm_addr);
        //[113, 13, 18, 0, 0, admin_address, context.amm_addr]
        ILPToken.initializer(contract_address=lpt_call_addr_btc, name=113, symbol=13, proxy_admin=admin_addr, owner=amm_addr);

        //[1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.mydoge_address, optype_call, ids.strike_price_doge, expiry, side_long]
        // opt_long_call_addr_doge
        IOptionToken.initializer(contract_address=opt_long_call_addr_doge, name=1234, symbol=14, proxy_admin=admin_addr, owner=amm_addr, quote_token_address=myusd_addr, base_token_address=mydoge_addr, option_type=optype_call, strike_price=strike_price_doge, maturity=expiry, side=side_long);
        // , [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.mydoge_address, optype_call, ids.strike_price_doge, expiry, side_short]
        // opt_short_call_addr_doge
        IOptionToken.initializer(contract_address=opt_short_call_addr_doge, name=1234, symbol=14, proxy_admin=admin_addr, owner=amm_addr, quote_token_address=myusd_addr, base_token_address=mydoge_addr, option_type=optype_call, strike_price=strike_price_doge, maturity=expiry, side=side_short);
        //, [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.mybtc_address, optype_call, ids.strike_price_btc, expiry, side_long]
        // opt_long_call_addr_btc
        IOptionToken.initializer(contract_address=opt_long_call_addr_btc, name=1234, symbol=14, proxy_admin=admin_addr, owner=amm_addr, quote_token_address=myusd_addr, base_token_address=mybtc_addr, option_type=optype_call, strike_price=strike_price_btc, maturity=expiry, side=side_long);
        // [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.mybtc_address, optype_call, ids.strike_price_btc, expiry, side_short]
        // opt_short_call_addr_btc
        IOptionToken.initializer(contract_address=opt_short_call_addr_btc, name=1234, symbol=14, proxy_admin=admin_addr, owner=amm_addr, quote_token_address=myusd_addr, base_token_address=mybtc_addr, option_type=optype_call, strike_price=strike_price_btc, maturity=expiry, side=side_short);
        
        let (balbtc) = IERC20.balanceOf(contract_address=mybtc_addr, account=admin_addr);
        assert balbtc.low = 100000000;

        let (baldoge) = IERC20.balanceOf(contract_address=mydoge_addr, account=admin_addr);
        assert baldoge.low = 10000000000000;
            
        let fifty_k_doge_math64 = 115292150460684697600000;
        let half_btc_math64 = 1152921504606846976;

        // Deploy LP Tokens
        IAMM.add_lptoken(
            contract_address=amm_addr, 
            quote_token_address=myusd_addr, 
            base_token_address=mybtc_addr, 
            option_type=0, 
            lptoken_address=lpt_call_addr_btc,
            pooled_token_addr = mybtc_addr,
            volatility_adjustment_speed = half_btc_math64,
            max_lpool_bal = Uint256(10000000000000, 0)
        );
        IAMM.add_lptoken(
            contract_address=amm_addr, 
            quote_token_address=myusd_addr, 
            base_token_address=mydoge_addr, 
            option_type=0, 
            lptoken_address=lpt_call_addr_doge,
            pooled_token_addr = mydoge_addr,
            volatility_adjustment_speed = fifty_k_doge_math64,
            max_lpool_bal = Uint256(10000000000000, 0)
        );

        // Approve funds to spend
        let max_127bit_number = 0x80000000000000000000000000000000;
        let approve_amt = Uint256(low = max_127bit_number, high = max_127bit_number);
        %{
            stop_prank_mybtc = start_prank(context.admin_address, context.mybtc_address)
        %}
        IERC20.approve(contract_address=mybtc_addr, spender=amm_addr, amount=approve_amt);

        %{
            stop_prank_mybtc()
            stop_prank_mydoge = start_prank(context.admin_address, context.mydoge_address)
        %}
        IERC20.approve(contract_address=mydoge_addr, spender=amm_addr, amount=approve_amt);

        %{
            stop_prank_mydoge()
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        %}
        // Deposit 50k Doge
        let fifty_k_doge = Uint256(low = 5000000000000, high = 0);
        IAMM.deposit_liquidity(contract_address=amm_addr, pooled_token_addr=mydoge_addr, quote_token_address=myusd_addr, base_token_address=mydoge_addr, option_type=0, amount=fifty_k_doge);
        let (bal_doge_lpt: Uint256) = ILPToken.balanceOf(contract_address=lpt_call_addr_doge, account=admin_addr);
        assert bal_doge_lpt.low = 5000000000000;

        // Deposit 0.5 BTC
        let half_btc = Uint256(low = 50000000, high = 0);
        IAMM.deposit_liquidity(contract_address=amm_addr, pooled_token_addr=mybtc_addr, quote_token_address=myusd_addr, base_token_address=mybtc_addr, option_type=0, amount=half_btc);
        let (bal_btc_lpt: Uint256) = ILPToken.balanceOf(contract_address=lpt_call_addr_btc, account=admin_addr);
        assert bal_btc_lpt.low = 50000000;

        // Add the options
        let hundred_m64x61 = Math64x61.fromFelt(100);
        // Add long call options
        IAMM.add_option(
            contract_address=amm_addr,
            option_side=side_long,
            maturity=expiry,
            strike_price=strike_price_btc,
            quote_token_address=myusd_addr,
            base_token_address=mybtc_addr,
            option_type=optype_call,
            lptoken_address=lpt_call_addr_btc,
            option_token_address_=opt_long_call_addr_btc,
            initial_volatility=hundred_m64x61
        );
        IAMM.add_option(
            contract_address=amm_addr,
            option_side=side_long,
            maturity=expiry,
            strike_price=strike_price_doge,
            quote_token_address=myusd_addr,
            base_token_address=mydoge_addr,
            option_type=optype_call,
            lptoken_address=lpt_call_addr_doge,
            option_token_address_=opt_long_call_addr_doge,
            initial_volatility=hundred_m64x61
        );
        // Add short call option
        IAMM.add_option(
            contract_address=amm_addr,
            option_side=side_short,
            maturity=expiry,
            strike_price=strike_price_btc,
            quote_token_address=myusd_addr,
            base_token_address=mybtc_addr,
            option_type=optype_call,
            lptoken_address=lpt_call_addr_btc,
            option_token_address_=opt_short_call_addr_btc,
            initial_volatility=hundred_m64x61
        );
        IAMM.add_option(
            contract_address=amm_addr,
            option_side=side_short,
            maturity=expiry,
            strike_price=strike_price_doge,
            quote_token_address=myusd_addr,
            base_token_address=mydoge_addr,
            option_type=optype_call,
            lptoken_address=lpt_call_addr_doge,
            option_token_address_=opt_short_call_addr_doge,
            initial_volatility=hundred_m64x61
        );

        
        return ();
    }

    func roundtrip_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
        alloc_locals;

        tempvar lpt_call_addr_btc;
        tempvar lpt_call_addr_doge;

        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar mydoge_addr;
        tempvar mybtc_addr;
        tempvar admin_addr;
        tempvar expiry;

        tempvar opt_long_call_addr_doge;
        tempvar opt_long_call_addr_btc;
        tempvar opt_short_call_addr_doge;
        tempvar opt_short_call_addr_btc;

        tempvar expiry;

        let strike_price_btc = Math64x61.fromFelt(20000);
        let strike_price_doge = 230584300921369408; // 0.1 * 2**61
        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            ids.lpt_call_addr_btc = context.lpt_call_addr_btc
            ids.lpt_call_addr_doge = context.lpt_call_addr_doge

            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.mydoge_addr = context.mydoge_address
            ids.mybtc_addr = context.mybtc_address
            ids.admin_addr = context.admin_address
            ids.expiry = context.expiry_0

            ids.opt_long_call_addr_doge = context.opt_long_call_addr_doge
            ids.opt_long_call_addr_btc = context.opt_long_call_addr_btc
            ids.opt_short_call_addr_doge = context.opt_long_call_addr_doge
            ids.opt_short_call_addr_btc = context.opt_long_call_addr_btc
            
            ids.expiry = context.expiry_0
        %}
        
        // Define inputs for get_stats function
        // BTC
        let input_long_btc = StatsInput (
            user_addr = admin_addr, 
            lpt_addr = lpt_call_addr_btc,
            amm_addr = amm_addr,
            opt_addr = opt_long_call_addr_btc,
            expiry = expiry,
            strike_price = strike_price_btc,
        );
        let input_short_btc = StatsInput (
            user_addr = admin_addr, 
            lpt_addr = lpt_call_addr_btc,
            amm_addr = amm_addr,
            opt_addr = opt_short_call_addr_btc,
            expiry = expiry,
            strike_price = strike_price_btc,
        );
        // Doge
        let input_long_doge = StatsInput (
            user_addr = admin_addr, 
            lpt_addr = lpt_call_addr_doge,
            amm_addr = amm_addr,
            opt_addr = opt_long_call_addr_doge,
            expiry = expiry,
            strike_price = strike_price_doge,
        );
        let input_short_doge = StatsInput (
            user_addr = admin_addr, 
            lpt_addr = lpt_call_addr_doge,
            amm_addr = amm_addr,
            opt_addr = opt_short_call_addr_doge,
            expiry = expiry,
            strike_price = strike_price_doge,
        );

        // Get first set of info   
        let (res_long_btc) = get_stats(input_long_btc);
        let (res_short_btc) = get_stats(input_short_btc);
        let (res_long_doge) = get_stats(input_long_doge);
        let (res_short_doge) = get_stats(input_short_doge);
        
        // Test initial balance of lp tokens 
        assert res_long_btc.bal_lpt = 50000000;
        assert res_long_doge.bal_lpt = 5000000000000;

        // Test unlocked capital in the pools
        assert res_long_btc.pool_unlocked_capital = 50000000;
        assert res_long_doge.pool_unlocked_capital = 5000000000000;
        
        // Test intiial balance of option tokens
        assert res_long_btc.bal_opt = 0;
        assert res_short_btc.bal_opt = 0;
        assert res_long_doge.bal_opt = 0;
        assert res_short_btc.bal_opt = 0;

        // Test pools volatility
        assert res_long_btc.pool_volatility = 230584300921369395200;
        assert res_long_doge.pool_volatility = 230584300921369395200;

        // Test option position from pool's perspective
        assert res_long_btc.opt_long_pos = 0; 
        assert res_long_btc.opt_short_pos = 0; 
        assert res_long_doge.opt_long_pos = 0; 
        assert res_long_doge.opt_short_pos = 0; 
        
        // Test lpool_balance
        assert res_long_btc.lpool_balance = 50000000;
        assert res_long_doge.lpool_balance = 5000000000000;

        // Test pool_locked_capital
        assert res_long_btc.pool_locked_capital = 0;
        assert res_long_doge.pool_locked_capital = 0;
        
        // TEst value od pools position
        assert res_long_btc.pool_position_val = 0;
        assert res_long_doge.pool_position_val = 0;
        
        // ///////////////////////////////////////////////////
        // // BUY THE CALL OPTIONS
        // ///////////////////////////////////////////////////

        tempvar myusd_addr;
        tempvar mybtc_addr;
        tempvar mydoge_addr;
        tempvar admin_addr;
        tempvar amm_addr;
        tempvar lpt_call_addr_btc;
        tempvar lpt_call_addr_doge;
        tempvar opt_long_call_addr_btc;
        tempvar opt_short_call_addr_btc;
        tempvar opt_long_call_addr_doge;
        tempvar opt_short_call_addr_doge;
        
        tempvar expiry;
        tempvar side_long;
        tempvar side_short;
        tempvar optype_call;
        tempvar optype_put;
        %{
            ids.expiry = expiry
            ids.optype_call = optype_call
            ids.optype_put = optype_put
            ids.side_long = side_long
            ids.side_short = side_short
            
            ids.mybtc_addr = context.mybtc_address
            ids.mydoge_addr = context.mydoge_address   
            ids.myusd_addr = context.myusd_address
            
            ids.amm_addr = context.amm_addr
            ids.admin_addr = admin_address
            
            ids.lpt_call_addr_btc = context.lpt_call_addr_btc
            ids.lpt_call_addr_doge = context.lpt_call_addr_doge
            
            ids.opt_long_call_addr_doge = context.opt_long_call_addr_doge
            ids.opt_short_call_addr_doge = context.opt_short_call_addr_doge
            ids.opt_long_call_addr_btc = context.opt_long_call_addr_btc
            ids.opt_short_call_addr_btc = context.opt_short_call_addr_btc
        %}
        
        %{ stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) %}

        let one = Math64x61.fromFelt(1);
        let ten = Math64x61.fromFelt(10);
        let tenth = 10000000; // 0.1 * 10**8
        let ten_k = 1000000000000; // 10_000 * 10 ** 8

        %{
            stop_mock_current_price_btc = mock_call(
                ids.tmp_address, "get_spot_median", [2100000000000, 8, 1000000000 + 60*60*12, 0]  # mock current BTC price at 21_000
            )
        %}

        let (btc_long_premia) = IAMM.trade_open(
            contract_address = amm_addr,
            option_type = 0,
            strike_price = strike_price_btc,
            maturity = expiry,
            option_side = 0,
            option_size = tenth,
            quote_token_address = myusd_addr,
            base_token_address = mybtc_addr,
            limit_total_premia = 230584300921369395200000, // 100_000 to disable it
            tx_deadline = 9999999999999999 // Disable deadline
        ); 
        assert btc_long_premia = 114979423560498977; // 1047.1519028495616 USD 

        let (res_long_btc_2) = get_stats(input_long_btc);
        let (res_short_btc_2) = get_stats(input_short_btc);

        %{
            stop_mock_current_price_btc()
            stop_mock_current_price_doge = mock_call(
                ids.tmp_address, "get_spot_median", [10000000, 8, 1000000000 + 60*60*12, 0]  # mock current DOGE price at 0.1  
            ) 
        %}
        let (doge_long_premia) = IAMM.trade_open(
            contract_address = amm_addr,
            option_type = 0,
            strike_price = strike_price_doge,
            maturity = expiry,
            option_side = 0,
            option_size = ten_k,
            quote_token_address = myusd_addr,
            base_token_address = mydoge_addr,
            limit_total_premia = 230584300921369395200000, // 100_000 to disable it
            tx_deadline = 9999999999999999 // Disable deadline
        ); 
        assert doge_long_premia = 36764604948327620; // Approx 0.01 USD
        
        let (res_long_doge_2) = get_stats(input_long_doge);
        let (res_short_doge_2) = get_stats(input_short_doge);

        %{ stop_mock_current_price_doge() %}

        // Test balance of lp tokens
        assert res_long_btc_2.bal_lpt = 50000000;
        assert res_long_doge_2.bal_lpt = 5000000000000;

        // Test balances in user account
        let (admin_mydoge_balance_2: Uint256) = IERC20.balanceOf(
            contract_address=mydoge_addr,
            account=admin_addr
        );
        assert admin_mydoge_balance_2.low = 4983577571004;

        let (admin_mybtc_balance_2: Uint256) = IERC20.balanceOf(
            contract_address=mybtc_addr,
            account=admin_addr
        );
        assert admin_mybtc_balance_2.low = 49486397;

        let (admin_myusd_balance_2: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myusd_balance_2.low = 5000000000;

        // Test inlocked capital in the pools 
        assert res_long_btc_2.pool_unlocked_capital = 40513603;
        assert res_long_doge_2.pool_unlocked_capital = 4016422428996;

        // Test balance of option tokens 
        assert res_long_btc_2.bal_opt = 10000000;
        assert res_short_btc_2.bal_opt = 10000000;
        assert res_long_doge_2.bal_opt = 1000000000000;
        assert res_short_doge_2.bal_opt = 1000000000000;

        // Test pool vol
        assert res_long_btc_2.pool_volatility = 276701161105643274200;
        assert res_long_doge_2.pool_volatility = 276701161105643274200;
        
        // Test pools position
        assert res_long_btc_2.opt_long_pos = 0; 
        assert res_long_btc_2.opt_short_pos = 10000000; 
        assert res_long_doge_2.opt_long_pos = 0; 
        assert res_long_doge_2.opt_short_pos = 1000000000000; 

        // Test lpool balance
        assert res_long_btc_2.lpool_balance = 50513603;
        assert res_long_doge_2.lpool_balance = 5016422428996;

        // Test pool locked capital
        assert res_long_btc_2.pool_locked_capital = 10000000;
        assert res_long_doge_2.pool_locked_capital = 1000000000000;

        // Test value of pools positions
        assert res_long_btc_2.pool_position_val = 218741420294638002;
        assert res_long_doge_2.pool_position_val = 22679754661169165034090;

        // ///////////////////////////////////////////////////
        // // WITHDRAW CAPITAL - WITHDRAW 20% of lp tokens
        // ///////////////////////////////////////////////////

        tempvar myusd_addr;
        tempvar mybtc_addr;
        tempvar mydoge_addr;
        tempvar admin_addr;
        tempvar amm_addr;
        tempvar lpt_call_addr_btc;
        tempvar lpt_call_addr_doge;
        tempvar opt_long_call_addr_btc;
        tempvar opt_short_call_addr_btc;
        tempvar opt_long_call_addr_doge;
        tempvar opt_short_call_addr_doge;
        
        tempvar expiry;
        tempvar side_long;
        tempvar side_short;
        tempvar optype_call;
        tempvar optype_put;
        %{
            ids.expiry = expiry
            ids.optype_call = optype_call
            ids.optype_put = optype_put
            ids.side_long = side_long
            ids.side_short = side_short
            
            ids.mybtc_addr = context.mybtc_address
            ids.mydoge_addr = context.mydoge_address   
            ids.myusd_addr = context.myusd_address
            
            ids.amm_addr = context.amm_addr
            ids.admin_addr = admin_address
            
            ids.lpt_call_addr_btc = context.lpt_call_addr_btc
            ids.lpt_call_addr_doge = context.lpt_call_addr_doge
            
            ids.opt_long_call_addr_doge = context.opt_long_call_addr_doge
            ids.opt_short_call_addr_doge = context.opt_short_call_addr_doge
            ids.opt_long_call_addr_btc = context.opt_long_call_addr_btc
            ids.opt_short_call_addr_btc = context.opt_short_call_addr_btc
        %}
         %{
            stop_mock_current_price_btc = mock_call(
                ids.tmp_address, "get_spot_median", [1900000000000, 8, 1000000000 + 60*60*12, 0]  # mock current BTC price at 19_000
            )
        %}
        let tenth_btc = Uint256(low = 10000000, high = 0);
        IAMM.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=mybtc_addr,
            quote_token_address=myusd_addr,
            base_token_address=mybtc_addr,
            option_type=0,
            lp_token_amount=tenth_btc
        );
        let (res_long_btc_3) = get_stats(input_long_btc);
        let (res_short_btc_3) = get_stats(input_short_btc);
        
        %{
            stop_mock_current_price_btc()
            stop_mock_current_price_doge = mock_call(
                ids.tmp_address, "get_spot_median", [9000000, 8, 1000000000 + 60*60*12, 0]  # mock current DOGE price at 0.09  
            ) 
        %}
        
        let ten_k_doge = Uint256(low = 1000000000000, high = 0);
        IAMM.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=mydoge_addr,
            quote_token_address=myusd_addr,
            base_token_address=mydoge_addr,
            option_type=0,
            lp_token_amount=ten_k_doge
        );
        let (res_long_doge_3) = get_stats(input_long_doge);
        let (res_short_doge_3) = get_stats(input_short_doge);
        
        %{ stop_mock_current_price_doge() %}
        
        // Test balances in user account
        let (admin_mydoge_balance_3: Uint256) = IERC20.balanceOf(
            contract_address=mydoge_addr,
            account=admin_addr
        );
        assert admin_mydoge_balance_3.low = 5986848680122;

        let (admin_mybtc_balance_3: Uint256) = IERC20.balanceOf(
            contract_address=mybtc_addr,
            account=admin_addr
        );
        assert admin_mybtc_balance_3.low = 59584837;

        let (admin_myusd_balance_3: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myusd_balance_3.low = 5000000000;

        // Test unlocked capital in the pools 
        assert res_long_btc_3.pool_unlocked_capital = 30415163;
        assert res_long_doge_3.pool_unlocked_capital = 3013151319878;
        
        // Test balance of option tokens 
        assert res_long_btc_3.bal_opt = 10000000;
        assert res_short_btc_3.bal_opt = 10000000;
        assert res_long_doge_3.bal_opt = 1000000000000;
        assert res_short_doge_3.bal_opt = 1000000000000;

        // Test pool vol
        assert res_long_btc_3.pool_volatility = 276701161105643274200;
        assert res_long_doge_3.pool_volatility = 276701161105643274200;

        // Test pools position
        assert res_long_btc_3.opt_long_pos = 0; 
        assert res_long_btc_3.opt_short_pos = 10000000; 
        assert res_long_doge_3.opt_long_pos = 0; 
        assert res_long_doge_3.opt_short_pos = 1000000000000; 
        
        // Test lpool balance
        assert res_long_btc_3.lpool_balance = 40415163;
        assert res_long_doge_3.lpool_balance = 4013151319878;
        
        // Test pool locked capital
        assert res_long_btc_3.pool_locked_capital = 10000000;
        assert res_long_doge_3.pool_locked_capital = 1000000000000;
        
        // Test value of pools positions
        assert res_long_btc_3.pool_position_val = 230090815745610101;
        assert res_long_doge_3.pool_position_val = 23056887865798717116901;


        // ///////////////////////////////////////////////////
        // // CLOSE HALF OF THE BOUGHT OPTIONS
        // ///////////////////////////////////////////////////
        let two = Math64x61.fromFelt(2);
        let twentieth = 5000000; // 0.05 * 10**8
        let five_k = Math64x61.div(ten_k, two);
        let tmp_address = EMPIRIC_ORACLE_ADDRESS;
        tempvar myusd_addr;
        tempvar mybtc_addr;
        tempvar mydoge_addr;
        tempvar admin_addr;
        tempvar amm_addr;
        tempvar lpt_call_addr_btc;
        tempvar lpt_call_addr_doge;
        tempvar opt_long_call_addr_btc;
        tempvar opt_short_call_addr_btc;
        tempvar opt_long_call_addr_doge;
        tempvar opt_short_call_addr_doge;
        
        tempvar expiry;
        tempvar side_long;
        tempvar side_short;
        tempvar optype_call;
        tempvar optype_put;
        %{
            ids.expiry = expiry
            ids.optype_call = optype_call
            ids.optype_put = optype_put
            ids.side_long = side_long
            ids.side_short = side_short
            
            ids.mybtc_addr = context.mybtc_address
            ids.mydoge_addr = context.mydoge_address   
            ids.myusd_addr = context.myusd_address
            
            ids.amm_addr = context.amm_addr
            ids.admin_addr = admin_address
            
            ids.lpt_call_addr_btc = context.lpt_call_addr_btc
            ids.lpt_call_addr_doge = context.lpt_call_addr_doge
            
            ids.opt_long_call_addr_doge = context.opt_long_call_addr_doge
            ids.opt_short_call_addr_doge = context.opt_short_call_addr_doge
            ids.opt_long_call_addr_btc = context.opt_long_call_addr_btc
            ids.opt_short_call_addr_btc = context.opt_short_call_addr_btc
        %}
        
        %{
            stop_mock_current_price_btc = mock_call(
                ids.tmp_address, "get_spot_median", [2100000000000, 8, 1000000000 + 60*60*12, 0]  # mock current BTC price at 21_000
            )
        %}

        let (btc_long_premia_3: Math64x61_) = IAMM.trade_close(
            contract_address = amm_addr,
            option_type = 0,
            strike_price = strike_price_btc,
            maturity = expiry,
            option_side = 0,
            option_size = twentieth,
            quote_token_address = myusd_addr,
            base_token_address = mybtc_addr,
            limit_total_premia = 1, // 100_000 to disable it
            tx_deadline = 9999999999999999 // Disable deadline
        );
        assert btc_long_premia_3 = 115818897479527712; // 1050.9163642941874 USD 

        let (res_long_btc_4) = get_stats(input_long_btc);
        let (res_short_btc_4) = get_stats(input_short_btc);
        
        %{
            stop_mock_current_price_btc()
            stop_mock_current_price_doge = mock_call(
                ids.tmp_address, "get_spot_median", [10000000, 8, 1000000000 + 60*60*12, 0]  # mock current DOGE price at 0.1  
            ) 
        %}
        let (doge_long_premia_3) = IAMM.trade_close(
            contract_address = amm_addr,
            option_type = 0,
            strike_price = strike_price_doge,
            maturity = expiry,
            option_side = 0,
            option_size = five_k,
            quote_token_address = myusd_addr,
            base_token_address = mydoge_addr,
            limit_total_premia = 1,
            tx_deadline = 9999999999999999 // Disable deadline
        ); 
        assert doge_long_premia_3 = 38474923256948840; // Approx 0.1 USD
        
        let (res_long_doge_4) = get_stats(input_long_doge);
        let (res_short_doge_4) = get_stats(input_short_doge);
        
        %{ stop_mock_current_price_doge() %}

        // Test balances in user account
        let (admin_mydoge_balance_4: Uint256) = IERC20.balanceOf(
            contract_address=mydoge_addr,
            account=admin_addr
        );
        assert admin_mydoge_balance_4.low = 5994941311625;

        let (admin_mybtc_balance_4: Uint256) = IERC20.balanceOf(
            contract_address=mybtc_addr,
            account=admin_addr
        );
        assert admin_mybtc_balance_4.low = 59828444;

        let (admin_myusd_balance_4: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myusd_balance_4.low = 5000000000;

        // Test unlocked capital in the pools 
        assert res_long_btc_4.pool_unlocked_capital = 35171556;
        assert res_long_doge_4.pool_unlocked_capital = 3505058688375;
        
        // // Test balance of option tokens 
        assert res_long_btc_4.bal_opt = 5000000;
        assert res_short_btc_4.bal_opt = 5000000;
        assert res_long_doge_4.bal_opt = 500000000000;
        assert res_short_doge_4.bal_opt = 500000000000;

        // // Test pool vol
        assert res_long_btc_4.pool_volatility = 253642731013506334800;
        assert res_long_doge_4.pool_volatility = 253642731013506334700;

        // // Test pools option position
        assert res_long_btc_4.opt_long_pos = 0; 
        assert res_long_btc_4.opt_short_pos = 5000000; 
        assert res_long_doge_4.opt_long_pos = 0; 
        assert res_long_doge_4.opt_short_pos = 500000000000; 

        // // Test lpool balance
        assert res_long_btc_4.lpool_balance = 40171556;
        assert res_long_doge_4.lpool_balance = 4005058688375;
        
        // // Test pool locked capital
        assert res_long_btc_4.pool_locked_capital = 5000000;
        assert res_long_doge_4.pool_locked_capital = 500000000000;
        
        // // Test value of pools positions
        assert res_long_btc_4.pool_position_val = 109411227349187644;
        assert res_long_doge_4.pool_position_val = 11348686066773419052543;

        ///////////////////////////////////////////////////
        // SELL THE CALL OPTIONS
        ///////////////////////////////////////////////////

        
        tempvar myusd_addr;
        tempvar mybtc_addr;
        tempvar mydoge_addr;
        tempvar admin_addr;
        tempvar amm_addr;
        tempvar lpt_call_addr_btc;
        tempvar lpt_call_addr_doge;
        tempvar opt_long_call_addr_btc;
        tempvar opt_short_call_addr_btc;
        tempvar opt_long_call_addr_doge;
        tempvar opt_short_call_addr_doge;
        
        tempvar expiry;
        tempvar side_long;
        tempvar side_short;
        tempvar optype_call;
        tempvar optype_put;
        %{
            ids.expiry = expiry
            ids.optype_call = optype_call
            ids.optype_put = optype_put
            ids.side_long = side_long
            ids.side_short = side_short
            
            ids.mybtc_addr = context.mybtc_address
            ids.mydoge_addr = context.mydoge_address   
            ids.myusd_addr = context.myusd_address
            
            ids.amm_addr = context.amm_addr
            ids.admin_addr = admin_address
            
            ids.lpt_call_addr_btc = context.lpt_call_addr_btc
            ids.lpt_call_addr_doge = context.lpt_call_addr_doge
            
            ids.opt_long_call_addr_doge = context.opt_long_call_addr_doge
            ids.opt_short_call_addr_doge = context.opt_short_call_addr_doge
            ids.opt_long_call_addr_btc = context.opt_long_call_addr_btc
            ids.opt_short_call_addr_btc = context.opt_short_call_addr_btc
        %}
        %{
            stop_mock_current_price_btc = mock_call(
                ids.tmp_address, "get_spot_median", [2100000000000, 8, 1000000000 + 60*60*12, 0]  # mock current BTC price at 21_000
            )
        %}

        let (btc_short_premia_4) = IAMM.trade_open(
            contract_address = amm_addr,
            option_type = 0,
            strike_price = strike_price_btc,
            maturity = expiry,
            option_side = 1,
            option_size = tenth,
            quote_token_address = myusd_addr,
            base_token_address = mybtc_addr,
            limit_total_premia = 1, // 100_000 to disable it
            tx_deadline = 9999999999999999 // Disable deadline
        ); 
        assert btc_short_premia_4 = 113462825200740447; // 1050.9163642941874 USD 

        let (res_long_btc_5) = get_stats(input_long_btc);
        let (res_short_btc_5) = get_stats(input_short_btc);

        %{
            stop_mock_current_price_btc()
            stop_mock_current_price_doge = mock_call(
                ids.tmp_address, "get_spot_median", [11000000, 8, 1000000000 + 60*60*12, 0]  # mock current DOGE price at 0.11
            ) 
        %}
        let (doge_short_premia_4) = IAMM.trade_open(
            contract_address = amm_addr,
            option_type = 0,
            strike_price = strike_price_doge,
            maturity = expiry,
            option_side = 1,
            option_size = ten_k,
            quote_token_address = myusd_addr,
            base_token_address = mydoge_addr,
            limit_total_premia = 1, // 100_000 to disable it
            tx_deadline = 9999999999999999 // Disable deadline
        ); 
        assert doge_short_premia_4 = 209750307908668600; // Approx 0.1 USD
        
        let (res_long_doge_5) = get_stats(input_long_doge);
        let (res_short_doge_5) = get_stats(input_short_doge);

        %{ stop_mock_current_price_doge() %}


        // // Test balances in user account
        let (admin_mydoge_balance_5: Uint256) = IERC20.balanceOf(
            contract_address=mydoge_addr,
            account=admin_addr
        );
        assert admin_mydoge_balance_5.low = 5083177066556;

        let (admin_mybtc_balance_5: Uint256) = IERC20.balanceOf(
            contract_address=mybtc_addr,
            account=admin_addr
        );
        assert admin_mybtc_balance_5.low = 50305748;

        let (admin_myusd_balance_5: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myusd_balance_5.low = 5000000000;

        // // Test balance of lp tokens
        assert res_long_btc_5.bal_lpt = 40000000;
        assert res_long_doge_5.bal_lpt = 4000000000000;

        // // Test unlocked capital in the pools 
        assert res_long_btc_5.pool_unlocked_capital = 39694252;
        assert res_long_doge_5.pool_unlocked_capital = 3916822933444;

        // // Test balance of option tokens 
        assert res_long_btc_5.bal_opt = 5000000;
        assert res_short_btc_5.bal_opt = 5000000;
        assert res_long_doge_5.bal_opt = 500000000000;
        assert res_short_doge_5.bal_opt = 500000000000;

        // // Test pool vol
        assert res_long_btc_5.pool_volatility = 207525870829232455800;
        assert res_long_doge_5.pool_volatility = 207525870829232455700;
        
        // // Test pools position
        assert res_long_btc_5.opt_long_pos = 5000000; 
        assert res_long_btc_5.opt_short_pos = 0; 
        assert res_long_doge_5.opt_long_pos = 500000000000; 
        assert res_long_doge_5.opt_short_pos = 0; 

        // // Test lpool balance
        assert res_long_btc_5.lpool_balance = 39694252;
        assert res_long_doge_5.lpool_balance = 3916822933444;

        // // Test pool locked capital
        assert res_long_btc_5.pool_locked_capital = 0;
        assert res_long_doge_5.pool_locked_capital = 0;

        // // Test value of pools positions
        assert res_long_btc_5.pool_position_val = 5470493211945800;
        assert res_long_doge_5.pool_position_val = 1017048592831519841605;

        ///////////////////////////////////////////////////
        // WITHDRAW CAPITAL - WITHDRAW another 20% (relative to initial amount) of lp tokens
        ///////////////////////////////////////////////////

        tempvar myusd_addr;
        tempvar mybtc_addr;
        tempvar mydoge_addr;
        tempvar admin_addr;
        tempvar amm_addr;
        tempvar lpt_call_addr_btc;
        tempvar lpt_call_addr_doge;
        tempvar opt_long_call_addr_btc;
        tempvar opt_short_call_addr_btc;
        tempvar opt_long_call_addr_doge;
        tempvar opt_short_call_addr_doge;
        
        tempvar expiry;
        tempvar side_long;
        tempvar side_short;
        tempvar optype_call;
        tempvar optype_put;
        %{
            ids.expiry = expiry
            ids.optype_call = optype_call
            ids.optype_put = optype_put
            ids.side_long = side_long
            ids.side_short = side_short
            
            ids.mybtc_addr = context.mybtc_address
            ids.mydoge_addr = context.mydoge_address   
            ids.myusd_addr = context.myusd_address
            
            ids.amm_addr = context.amm_addr
            ids.admin_addr = admin_address
            
            ids.lpt_call_addr_btc = context.lpt_call_addr_btc
            ids.lpt_call_addr_doge = context.lpt_call_addr_doge
            
            ids.opt_long_call_addr_doge = context.opt_long_call_addr_doge
            ids.opt_short_call_addr_doge = context.opt_short_call_addr_doge
            ids.opt_long_call_addr_btc = context.opt_long_call_addr_btc
            ids.opt_short_call_addr_btc = context.opt_short_call_addr_btc
        %}
         %{
            stop_mock_current_price_btc = mock_call(
                ids.tmp_address, "get_spot_median", [1900000000000, 8, 1000000000 + 60*60*12, 0]  # mock current BTC price at 19_000
            )
        %}
        let tenth_btc = Uint256(low = 10000000, high = 0);
        IAMM.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=mybtc_addr,
            quote_token_address=myusd_addr,
            base_token_address=mybtc_addr,
            option_type=0,
            lp_token_amount=tenth_btc
        );
        let (res_long_btc_6) = get_stats(input_long_btc);
        let (res_short_btc_6) = get_stats(input_short_btc);
        
        %{
            stop_mock_current_price_btc()
            stop_mock_current_price_doge = mock_call(
                ids.tmp_address, "get_spot_median", [9000000, 8, 1000000000 + 60*60*12, 0]  # mock current DOGE price at 0.09  
            ) 
        %}
        
        let ten_k_doge = Uint256(low = 1000000000000, high = 0);
        IAMM.withdraw_liquidity(
            contract_address=amm_addr,
            pooled_token_addr=mydoge_addr,
            quote_token_address=myusd_addr,
            base_token_address=mydoge_addr,
            option_type=0,
            lp_token_amount=ten_k_doge
        );
        let (res_long_doge_6) = get_stats(input_long_doge);
        let (res_short_doge_6) = get_stats(input_short_doge);
        
        %{ stop_mock_current_price_doge() %}
        
        // Test balances in user account
        let (admin_mydoge_balance_6: Uint256) = IERC20.balanceOf(
            contract_address=mydoge_addr,
            account=admin_addr
        );
        assert admin_mydoge_balance_6.low = 6062384525173;

        let (admin_mybtc_balance_6: Uint256) = IERC20.balanceOf(
            contract_address=mybtc_addr,
            account=admin_addr
        );
        assert admin_mybtc_balance_6.low = 60230722;

        let (admin_myusd_balance_6: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myusd_balance_6.low = 5000000000;

        // Test unlocked capital in the pools 
        assert res_long_btc_6.pool_unlocked_capital = 29769278;
        assert res_long_doge_6.pool_unlocked_capital = 2937615474827;
        
        // Test balance of option tokens 
        assert res_long_btc_6.bal_opt = 5000000;
        assert res_short_btc_6.bal_opt = 5000000;
        assert res_long_doge_6.bal_opt = 500000000000;
        assert res_short_doge_6.bal_opt = 500000000000;
        
        // Test pool vol
        assert res_long_btc_6.pool_volatility = 207525870829232455800;
        assert res_long_doge_6.pool_volatility = 207525870829232455700;

        // Test pools position
        assert res_long_btc_6.opt_long_pos = 5000000; 
        assert res_long_btc_6.opt_short_pos = 0; 
        assert res_long_doge_6.opt_long_pos = 500000000000; 
        assert res_long_doge_6.opt_short_pos = 0; 
        
        // Test lpool balance
        assert res_long_btc_6.lpool_balance = 29769278;
        assert res_long_doge_6.lpool_balance = 2937615474827;
        
        // Test pool locked capital
        assert res_long_btc_6.pool_locked_capital = 0;
        assert res_long_doge_6.pool_locked_capital = 0;
        
        // Test value of pools positions
        assert res_long_btc_6.pool_position_val = 130191606755248;
        assert res_long_doge_6.pool_position_val = 159126853200658401;

        
        // ///////////////////////////////////////////////////
        // // CLOSE HALF OF THE SOLD OPTIONS
        // ///////////////////////////////////////////////////

        
        %{
            stop_mock_current_price_btc = mock_call(
                ids.tmp_address, "get_spot_median", [2100000000000, 8, 1000000000 + 60*60*12, 0]  # mock current BTC price at 21_000
            )
        %}
        let (btc_long_premia_5: Math64x61_) = IAMM.trade_close(
            contract_address = amm_addr,
            option_type = 0,
            strike_price = strike_price_btc,
            maturity = expiry,
            option_side = 1,
            option_size = twentieth,
            quote_token_address = myusd_addr,
            base_token_address = mybtc_addr,
            limit_total_premia = 230584300921369395200000, // 100_000 to disable it
            tx_deadline = 9999999999999999 // Disable deadline
        );
        assert btc_long_premia_5 = 112793674473109264;

        let (res_long_btc_7) = get_stats(input_long_btc);
        let (res_short_btc_7) = get_stats(input_short_btc);
        
        %{
            stop_mock_current_price_btc()
            stop_mock_current_price_doge = mock_call(
                ids.tmp_address, "get_spot_median", [11000000, 8, 1000000000 + 60*60*12, 0]  # mock current DOGE price at 0.1  
            ) 
        %}
        let (doge_long_premia_5) = IAMM.trade_close(
            contract_address = amm_addr,
            option_type = 0,
            strike_price = strike_price_doge,
            maturity = expiry,
            option_side = 1,
            option_size = five_k,
            quote_token_address = myusd_addr,
            base_token_address = mydoge_addr,
            limit_total_premia = 230584300921369395200000, // 100_000 to disable it
            tx_deadline = 9999999999999999 // Disable deadline
        ); 
        assert doge_long_premia_5 = 209700740790004091;

        let (res_long_doge_7) = get_stats(input_long_doge);
        let (res_short_doge_7) = get_stats(input_short_doge);
        
        %{ stop_mock_current_price_doge() %}

        // Test balances in user account
        let (admin_mydoge_balance_7: Uint256) = IERC20.balanceOf(
            contract_address=mydoge_addr,
            account=admin_addr
        );
        assert admin_mydoge_balance_7.low = 6515548777434;

        let (admin_mybtc_balance_7: Uint256) = IERC20.balanceOf(
            contract_address=mybtc_addr,
            account=admin_addr
        );
        assert admin_mybtc_balance_7.low = 64978803;

        let (admin_myusd_balance_7: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myusd_balance_7.low = 5000000000;

        // // Test unlocked capital in the pools 
        assert res_long_btc_7.pool_unlocked_capital = 30021197;
        assert res_long_doge_7.pool_unlocked_capital = 2984451222566;

        // // Test balance of option tokens 
        assert res_long_btc_7.bal_opt = 5000000;
        assert res_short_btc_7.bal_opt = 5000000;
        assert res_long_doge_7.bal_opt = 500000000000;
        assert res_short_doge_7.bal_opt = 500000000000;

        // // Test pool vol
        assert res_long_btc_7.pool_volatility = 230584300921369395200;
        assert res_long_doge_7.pool_volatility = 230584300921369395200;

        // // Test pools position
        assert res_long_btc_7.opt_long_pos = 0; 
        assert res_long_btc_7.opt_short_pos = 0; 
        assert res_long_doge_7.opt_long_pos = 0; 
        assert res_long_doge_7.opt_short_pos = 0; 

        // // Test lpool balance
        assert res_long_btc_7.lpool_balance = 30021197;
        assert res_long_doge_7.lpool_balance = 2984451222566;
        
        // // Test pool locked capital
        assert res_long_btc_7.pool_locked_capital = 0;
        assert res_long_doge_7.pool_locked_capital = 0;
        
        // // Test value of pools positions
        assert res_long_btc_7.pool_position_val = 0;
        assert res_long_doge_7.pool_position_val = 0;

        // ///////////////////////////////////////////////////
        // // SETTLE (EXPIRE) POOL
        // ///////////////////////////////////////////////////

        tempvar myusd_addr;
        tempvar mybtc_addr;
        tempvar mydoge_addr;
        tempvar admin_addr;
        tempvar amm_addr;
        tempvar lpt_call_addr_btc;
        tempvar lpt_call_addr_doge;
        tempvar opt_long_call_addr_btc;
        tempvar opt_short_call_addr_btc;
        tempvar opt_long_call_addr_doge;
        tempvar opt_short_call_addr_doge;
        
        tempvar expiry;
        tempvar side_long;
        tempvar side_short;
        tempvar optype_call;
        tempvar optype_put;
        %{
            ids.expiry = expiry
            ids.optype_call = optype_call
            ids.optype_put = optype_put
            ids.side_long = side_long
            ids.side_short = side_short
            
            ids.mybtc_addr = context.mybtc_address
            ids.mydoge_addr = context.mydoge_address   
            ids.myusd_addr = context.myusd_address
            
            ids.amm_addr = context.amm_addr
            ids.admin_addr = admin_address
            
            ids.lpt_call_addr_btc = context.lpt_call_addr_btc
            ids.lpt_call_addr_doge = context.lpt_call_addr_doge
            
            ids.opt_long_call_addr_doge = context.opt_long_call_addr_doge
            ids.opt_short_call_addr_doge = context.opt_short_call_addr_doge
            ids.opt_long_call_addr_btc = context.opt_long_call_addr_btc
            ids.opt_short_call_addr_btc = context.opt_short_call_addr_btc
        %}

        %{
            stop_warp_1()
            # Set the time 1 second AFTER expiry
            stop_warp_2 = warp(1000000000 + 60*60*24 + 1, target_contract_address=ids.amm_addr)

            # Mock the terminal price for BTC
            stop_mock_terminal_price_btc = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [1000000000 + 60*60*24, 2100000000000, 0, 0, 0]  # mock terminal BTC price at 21_000
            )
        %}

        IAMM.expire_option_token_for_pool(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr_btc,
            option_side=0,
            strike_price=strike_price_btc,
            maturity=expiry,
        );
        IAMM.expire_option_token_for_pool(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr_btc,
            option_side=1,
            strike_price=strike_price_btc,
            maturity=expiry,
        );
        
        let (res_long_btc_8) = get_stats(input_long_btc);
        let (res_short_btc_8) = get_stats(input_short_btc);

        %{ 
            stop_mock_terminal_price_btc() 
            # Mock the terminal price for DOGE
            stop_mock_terminal_price_doge = mock_call(
                ids.tmp_address, "get_last_checkpoint_before", [1000000000 + 60*60*24, 15000000, 0, 0, 0]  # mock terminal DOGE at 0.15
            )
        %}
        
        IAMM.expire_option_token_for_pool(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr_doge,
            option_side=0,
            strike_price=strike_price_doge,
            maturity=expiry,
        );
        IAMM.expire_option_token_for_pool(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr_doge,
            option_side=1,
            strike_price=strike_price_doge,
            maturity=expiry,
        );
        
        let (res_long_doge_8) = get_stats(input_long_doge);
        let (res_short_doge_8) = get_stats(input_short_doge);

        %{ stop_mock_terminal_price_doge() %}

        // Test balances in user account
        let (admin_mydoge_balance_8: Uint256) = IERC20.balanceOf(
            contract_address=mydoge_addr,
            account=admin_addr
        );
        assert admin_mydoge_balance_8.low = 6515548777434;

        let (admin_mybtc_balance_8: Uint256) = IERC20.balanceOf(
            contract_address=mybtc_addr,
            account=admin_addr
        );
        assert admin_mybtc_balance_8.low = 64978803;

        let (admin_myusd_balance_8: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myusd_balance_8.low = 5000000000;

        // // Test unlocked capital in the pools 
        assert res_long_btc_8.pool_unlocked_capital = 30021197;
        assert res_long_doge_8.pool_unlocked_capital = 2984451222566;

        // // Test balance of option tokens 
        assert res_long_btc_8.bal_opt = 5000000;
        assert res_short_btc_8.bal_opt = 5000000;
        assert res_long_doge_8.bal_opt = 500000000000;
        assert res_short_doge_8.bal_opt = 500000000000;

        // // Test pool vol
        assert res_long_btc_8.pool_volatility = 230584300921369395200;
        assert res_long_doge_8.pool_volatility = 230584300921369395200;

        // Test pools position
        assert res_long_btc_8.opt_long_pos = 0; 
        assert res_long_btc_8.opt_short_pos = 0; 
        assert res_long_doge_8.opt_long_pos = 0; 
        assert res_long_doge_8.opt_short_pos = 0; 

        // Test lpool balance
        assert res_long_btc_8.lpool_balance = 30021197;
        assert res_long_doge_8.lpool_balance = 2984451222566;
        
        // Test pool locked capital
        assert res_long_btc_8.pool_locked_capital = 0;
        assert res_long_doge_8.pool_locked_capital = 0;
        
        // // Test value of pools positions
        assert res_long_btc_8.pool_position_val = 0;
        assert res_long_doge_8.pool_position_val = 0;

        ///////////////////////////////////////////////////
        // SETTLE OPTIONS
        ///////////////////////////////////////////////////

        %{
            stop_warp_1()
            # Set the time 1 second AFTER expiry
            stop_warp_2 = warp(1000000000 + 60*60*24 + 1, target_contract_address=ids.amm_addr)

            # Mock the terminal price for BTC
            stop_mock_terminal_price_btc = mock_call(
                ids.tmp_address, "get_last_spot_checkpoint_before", [1000000000 + 60*60*24, 2100000000000, 0, 0, 0]  # mock terminal BTC price at 21_000
            )
        %}

        IAMM.trade_settle(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price_btc,
            maturity=expiry,
            option_side=0,
            option_size=twentieth,
            quote_token_address=myusd_addr,
            base_token_address=mybtc_addr
        );
        IAMM.trade_settle(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price_btc,
            maturity=expiry,
            option_side=1,
            option_size=twentieth,
            quote_token_address=myusd_addr,
            base_token_address=mybtc_addr
        );
        
        let (res_long_btc_9) = get_stats(input_long_btc);
        let (res_short_btc_9) = get_stats(input_short_btc);

        %{ 
            stop_mock_terminal_price_btc() 
            # Mock the terminal price for DOGE
            stop_mock_terminal_price_doge = mock_call(
                ids.tmp_address, "get_last_spot_checkpoint_before", [1000000000 + 60*60*24, 15000000, 0, 0, 0]  # mock terminal DOGE at 0.15
            )
        %}
        
        IAMM.trade_settle(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price_doge,
            maturity=expiry,
            option_side=1,
            option_size=five_k,
            quote_token_address=myusd_addr,
            base_token_address=mydoge_addr
        );

        IAMM.trade_settle(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price_doge,
            maturity=expiry,
            option_side=0,
            option_size=five_k,
            quote_token_address=myusd_addr,
            base_token_address=mydoge_addr
        );

        let (res_long_doge_9) = get_stats(input_long_doge);
        let (res_short_doge_9) = get_stats(input_short_doge);
        
        %{ stop_mock_terminal_price_doge() %}

        // Test balances in user account
        let (admin_mydoge_balance_9: Uint256) = IERC20.balanceOf(
            contract_address=mydoge_addr,
            account=admin_addr
        );
        assert admin_mydoge_balance_9.low = 7015548777433;

        let (admin_mybtc_balance_9: Uint256) = IERC20.balanceOf(
            contract_address=mybtc_addr,
            account=admin_addr
        );
        assert admin_mybtc_balance_9.low = 69978802;

        let (admin_myusd_balance_9: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myusd_balance_9.low = 5000000000;

        // // Test unlocked capital in the pools 
        assert res_long_btc_9.pool_unlocked_capital = 30021197;
        assert res_long_doge_9.pool_unlocked_capital = 2984451222566;

        // // Test balance of option tokens 
        assert res_long_btc_9.bal_opt = 0;
        assert res_short_btc_9.bal_opt = 0;
        assert res_long_doge_9.bal_opt = 0;
        assert res_short_doge_9.bal_opt = 0;

        // // Test pool vol
        assert res_long_btc_9.pool_volatility = 230584300921369395200;
        assert res_long_doge_9.pool_volatility = 230584300921369395200;

        // Test pools position
        assert res_long_btc_9.opt_long_pos = 0; 
        assert res_long_btc_9.opt_short_pos = 0; 
        assert res_long_doge_9.opt_long_pos = 0; 
        assert res_long_doge_9.opt_short_pos = 0; 

        // Test lpool balance
        assert res_long_btc_9.lpool_balance = 30021197;
        assert res_long_doge_9.lpool_balance = 2984451222566;
        
        // Test pool locked capital
        assert res_long_btc_9.pool_locked_capital = 0;
        assert res_long_doge_9.pool_locked_capital = 0;
        
        // // Test value of pools positions
        assert res_long_btc_9.pool_position_val = 0;
        assert res_long_doge_9.pool_position_val = 0;

        return();
    }

    func min_round_trip_non_eth{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
        alloc_locals;
        additional_setup();
        roundtrip_call();
        
        return ();
    }


}
