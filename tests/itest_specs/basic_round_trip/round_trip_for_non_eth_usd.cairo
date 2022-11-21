%lang starknet
// FIXME: TBD
// test something weird... for example different number of decimals in base token (different than 18)

from constants import EMPIRIC_ORACLE_ADDRESS
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from openzeppelin.token.erc20.IERC20 import IERC20
from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool
from interface_option_token import IOptionToken
from interface_amm import IAMM
from types import Math64x61_
from math64x61 import Math64x61

// Struct containing informations about the amm 
//  -> to prevent spaghetti-like long tuples of unpacked variables
struct Stats {
    bal_lpt: felt,
    bal_opt: felt,
    pool_unlocked_capital: felt,
    pool_locked_capital: felt,
    lpool_balance: felt,
    pool_volatility: felt,
    opt_long_pos: felt,
    opt_short_pos: felt,
    pool_position_val: felt,
}

// Struct cointaing input data for get_stats function, 
// again to prevent spaghetti like code
struct StatsInput {
    user_addr: felt,
    lpt_addr: felt,
    amm_addr: felt,
    opt_addr: felt,
    expiry: felt,
    strike_price: felt,
}

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
            context.lpt_call_addr_doge = deploy_contract("./contracts/lptoken.cairo", [112, 12, 18, 0, 0, admin_address, context.amm_addr]).contract_address
            context.lpt_call_addr_btc = deploy_contract("./contracts/lptoken.cairo", [113, 13, 18, 0, 0, admin_address, context.amm_addr]).contract_address 
            
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
            
            context.opt_long_call_addr_doge = deploy_contract("./contracts/option_token.cairo", [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.mydoge_address, optype_call, ids.strike_price_doge, expiry, side_long]).contract_address
            context.opt_short_call_addr_doge = deploy_contract("./contracts/option_token.cairo", [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.mydoge_address, optype_call, ids.strike_price_doge, expiry, side_short]).contract_address
            
            context.opt_long_call_addr_btc = deploy_contract("./contracts/option_token.cairo", [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.mybtc_address, optype_call, ids.strike_price_btc, expiry, side_long]).contract_address
            context.opt_short_call_addr_btc = deploy_contract("./contracts/option_token.cairo", [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.mybtc_address, optype_call, ids.strike_price_btc, expiry, side_short]).contract_address
            
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
        
        let (balbtc) = IERC20.balanceOf(contract_address=mybtc_addr, account=admin_addr);
        assert balbtc.low = 100000000;

        let (baldoge) = IERC20.balanceOf(contract_address=mydoge_addr, account=admin_addr);
        assert baldoge.low = 10000000000000;
            
        // Deploy LP Tokens
        ILiquidityPool.add_lptoken(contract_address=amm_addr, quote_token_address=myusd_addr, base_token_address=mybtc_addr, option_type=0, lptoken_address=lpt_call_addr_btc);
        ILiquidityPool.add_lptoken(contract_address=amm_addr, quote_token_address=myusd_addr, base_token_address=mydoge_addr, option_type=0, lptoken_address=lpt_call_addr_doge);

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
        ILiquidityPool.deposit_liquidity(contract_address=amm_addr, pooled_token_addr=mydoge_addr, quote_token_address=myusd_addr, base_token_address=mydoge_addr, option_type=0, amount=fifty_k_doge);
        let (bal_doge_lpt: Uint256) = ILPToken.balanceOf(contract_address=lpt_call_addr_doge, account=admin_addr);
        assert bal_doge_lpt.low = 5000000000000;

        // Deposit 0.5 BTC
        let half_btc = Uint256(low = 50000000, high = 0);
        ILiquidityPool.deposit_liquidity(contract_address=amm_addr, pooled_token_addr=mybtc_addr, quote_token_address=myusd_addr, base_token_address=mybtc_addr, option_type=0, amount=half_btc);
        let (bal_btc_lpt: Uint256) = ILPToken.balanceOf(contract_address=lpt_call_addr_btc, account=admin_addr);
        assert bal_btc_lpt.low = 50000000;

        // Add the options
        let hundred_m64x61 = Math64x61.fromFelt(100);
        // Add long call options
        ILiquidityPool.add_option(
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
        ILiquidityPool.add_option(
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
        ILiquidityPool.add_option(
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
        ILiquidityPool.add_option(
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

    func get_stats{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        input: StatsInput
    ) -> (
        stats: Stats
    ){
        alloc_locals;

        let (bal_lpt: Uint256) = ILPToken.balanceOf(
            contract_address=input.lpt_addr,
            account=input.user_addr
        );
        let (pool_unlocked_capital) = ILiquidityPool.get_unlocked_capital(
            contract_address=input.amm_addr,
            lptoken_address=input.lpt_addr
        );
        let (bal_opt_tokens: Uint256) = IOptionToken.balanceOf(
            contract_address=input.opt_addr,
            account=input.user_addr
        );
        let (pool_volatility) = ILiquidityPool.get_pool_volatility(
            contract_address=input.amm_addr,
            lptoken_address=input.lpt_addr,
            maturity=input.expiry
        );
        let (opt_long_pos) = ILiquidityPool.get_pools_option_position(
            contract_address=input.amm_addr,
            lptoken_address=input.lpt_addr,
            option_side=0,
            maturity=input.expiry,
            strike_price=input.strike_price
        );
        let (opt_short_pos) = ILiquidityPool.get_pools_option_position(
            contract_address=input.amm_addr,
            lptoken_address=input.lpt_addr,
            option_side=1,
            maturity=input.expiry,
            strike_price=input.strike_price
        );
        let (lpool_balance) = ILiquidityPool.get_lpool_balance(
            contract_address=input.amm_addr,
            lptoken_address=input.lpt_addr
        );
        let (pool_locked_capital) = ILiquidityPool.get_pool_locked_capital(
            contract_address=input.amm_addr,
            lptoken_address=input.lpt_addr
        );
        let (pools_pos_val) = ILiquidityPool.get_value_of_pool_position(
            contract_address = input.amm_addr,
            lptoken_address = input.lpt_addr
        );
        let bal_low = bal_lpt.low;
        let opt_bal_low = bal_opt_tokens.low;

        let stats = Stats(
            bal_lpt = bal_low,
            bal_opt = opt_bal_low,
            pool_unlocked_capital = pool_unlocked_capital,
            pool_locked_capital = pool_locked_capital,
            lpool_balance = lpool_balance,
            pool_volatility = pool_volatility,
            opt_long_pos = opt_long_pos,
            opt_short_pos = opt_short_pos,
            pool_position_val = pools_pos_val,
        );

        return(stats,);
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
        assert res_long_btc.pool_unlocked_capital = 1152921504606846976;
        assert res_long_doge.pool_unlocked_capital = 115292150460684697600000;
        
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
        assert res_long_btc.lpool_balance = 1152921504606846976;
        assert res_long_doge.lpool_balance = 115292150460684697600000;

        // Test pool_locked_capital
        assert res_long_btc.pool_locked_capital = 0;
        assert res_long_doge.pool_locked_capital = 0;
        
        // TEst value od pools position
        assert res_long_btc.pool_position_val = 0;
        assert res_long_doge.pool_position_val = 0;
        
        ///////////////////////////////////////////////////
        // BUY THE CALL OPTIONS
        ///////////////////////////////////////////////////
        %{ stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) %}

        let one = Math64x61.fromFelt(1);
        let ten = Math64x61.fromFelt(10);
        let tenth = Math64x61.div(one, ten);
        let ten_k = Math64x61.fromFelt(10000);

        %{
            stop_mock_current_price_btc = mock_call(
                ids.tmp_address, "get_spot_median", [2100000000000, 8, 0, 0]  # mock current BTC price at 21_000
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
            base_token_address = mybtc_addr
        ); 
        assert btc_long_premia = 115392769136953499; // 1050.9163642941874 USD 

        let (res_long_btc_2) = get_stats(input_long_btc);
        let (res_short_btc_2) = get_stats(input_short_btc);

        %{
            stop_mock_current_price_btc()
            stop_mock_current_price_doge = mock_call(
                ids.tmp_address, "get_spot_median", [11000000, 8, 0, 0]  # mock current DOGE price at 0.1  FIXME: fails when spot median returns 0.05
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
            base_token_address = mydoge_addr
        ); 
        assert doge_long_premia = 209967107235339564; // Approx 0.1 USD
        
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
        assert admin_mydoge_balance_2.low = 4906209520949;

        let (admin_mybtc_balance_2: Uint256) = IERC20.balanceOf(
            contract_address=mybtc_addr,
            account=admin_addr
        );
        assert admin_mybtc_balance_2.low = 49484551;

        let (admin_myusd_balance_2: Uint256) = IERC20.balanceOf(
            contract_address=myusd_addr,
            account=admin_addr
        );
        assert admin_myusd_balance_2.low = 5000000000;

        // Test inlocked capital in the pools 
        assert res_long_btc_2.pool_unlocked_capital = 934222658906583790;
        assert res_long_doge_2.pool_unlocked_capital = 94396381573071755588690;

        // Test balance of option tokens 
        // FIXME: BTC OPT balance is wrong
        assert res_long_btc_2.bal_opt = 9999999;
        assert res_short_btc_2.bal_opt = 9999999;
        assert res_long_doge_2.bal_opt = 1000000000000;
        assert res_short_doge_2.bal_opt = 1000000000000;

        // Test pool vol
        assert res_long_btc_2.pool_volatility = 288230376151711743900;
        assert res_long_doge_2.pool_volatility = 288230376151711743900;
        
        // Test pools position
        assert res_long_btc_2.opt_long_pos = 0; 
        assert res_long_btc_2.opt_short_pos = 230584300921369395; 
        assert res_long_doge_2.opt_long_pos = 0; 
        assert res_long_doge_2.opt_short_pos = 23058430092136939520000; 

        // Test lpool balance
        assert res_long_btc_2.lpool_balance = 1164806959827953185;
        assert res_long_doge_2.lpool_balance = 117454811665208695108690;

        // Test pool locked capital
        assert res_long_btc_2.pool_locked_capital = 230584300921369395;
        assert res_long_doge_2.pool_locked_capital = 23058430092136939520000;

        // Test value of pools positions
        assert res_long_btc_2.pool_position_val = 218696637997535849;
        assert res_long_doge_2.pool_position_val = 20895712607624488341310;

        ///////////////////////////////////////////////////
        // WITHDRAW CAPITAL - WITHDRAW 20% of lp tokens
        ///////////////////////////////////////////////////
         %{
            stop_mock_current_price_btc = mock_call(
                ids.tmp_address, "get_spot_median", [2100000000000, 8, 0, 0]  # mock current BTC price at 21_000
            )
        %}
        let tenth_btc = Uint256(low = 10000000, high = 0);
        ILiquidityPool.withdraw_liquidity(
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
                ids.tmp_address, "get_spot_median", [11000000, 8, 0, 0]  # mock current DOGE price at 0.1  FIXME: fails when spot median returns 0.05
            ) 
        %}
        
        let ten_k_doge = Uint256(low = 1000000000000, high = 0);
        ILiquidityPool.withdraw_liquidity(
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
        
        
        %{
            print(f"{ids.admin_mydoge_balance_2.low}")
            print(f"{ids.admin_mybtc_balance_2.low}")
            print(f"{ids.admin_myusd_balance_2.low}")
            print(f"{ids.btc_long_premia}")
            print(f"{ids.doge_long_premia}")
        %}
        
        print_stats(res_long_btc_2);
        print_stats(res_short_btc_2);
        print_stats(res_long_doge_2);
        print_stats(res_short_doge_2);
        

        return();
    }

    func min_round_trip_non_eth{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
        alloc_locals;
        additional_setup();
        roundtrip_call();
        // roundtrip_put();
        
        return ();
    }

    func print_stats{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(stats: Stats){
        alloc_locals;

        let lpt = stats.bal_lpt;
        let opt = stats.bal_opt;
        let puc = stats.pool_unlocked_capital;
        let plc = stats.pool_locked_capital;
        let lpb = stats.lpool_balance;
        let pv = stats.pool_volatility;
        let olp = stats.opt_long_pos;
        let osp = stats.opt_short_pos;
        let ppv = stats.pool_position_val;

        %{
            print("=================STATS=================")
            print(str(ids.lpt))
            print(str(ids.opt))
            print(str(ids.puc))
            print(str(ids.plc))
            print(str(ids.lpb))
            print(str(ids.pv))
            print(str(ids.olp))
            print(str(ids.osp))
            print(str(ids.ppv))
        %}
    

        return ();
    }

}