%lang starknet

from math64x61 import Math64x61

from types import Math64x61_
from tests.itest_specs.setup import deploy_setup
from interface_amm import IAMM
from constants import EMPIRIC_ORACLE_ADDRESS
from interface_liquidity_pool import ILiquidityPool

@external
func __setup__{syscall_ptr: felt*, range_check_ptr}(){

    deploy_setup();

    return ();
}
// How value of pool position works(side of a position is from perspective of the pool):
//      In case of long position in given option, the value is equal to premia - fees.
//      In case of short position the value is equal to (locked capital - premia - fees).

@external 
func test_get_value_of_pool_position{syscall_ptr: felt*, range_check_ptr}(){
    alloc_locals;

    
    tempvar lpt_call_addr;
    tempvar lpt_put_addr;
    tempvar amm_addr;
    tempvar myusd_addr;
    tempvar myeth_addr;
    tempvar admin_addr;
    tempvar expiry;
    tempvar opt_long_call_addr;

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

    tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;

    %{
        stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        stop_warp_1 = warp(1000000000, target_contract_address=ids.amm_addr)
        stop_mock_current_price_1 = mock_call(
            ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
        )
    %}

    // Test value of pools position -> Should be zero
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
    
    // Buy single long call and put option
    let strike_price = Math64x61.fromFelt(1500);
    let one = Math64x61.fromFelt(1);

    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    let (pools_pos_val_call_2) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_call_addr
    );
    // 1 - premia - fee -> the user is long, pool is short
    // 1 - 0.0036382362035675903 - 0.0036382362035675903 * 0.03
    assert pools_pos_val_call_2 = 2297202131652353520;
        
    let (pools_pos_val_put_2) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_put_addr
    );
    // 1500 - premia - fee -> the user is long, pool is short
    // 1500 - 106.6060193865178 - 106.6060193865178 * 0.03
    assert pools_pos_val_put_2 = 3205573266941764271305;

    // Close both positions
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    // Test value of pools position -> Should be zero
    let (pools_pos_val_call_3) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_call_addr
    );
    assert pools_pos_val_call_3 = 0;
        
    let (pools_pos_val_put_3) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_put_addr
    );
    assert pools_pos_val_put_3 = 0;

    // Open call/put short positions
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    let (pools_pos_val_call_4) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_call_addr
    );
    // Premia - fees -> User is short, pool is long
    // 0.004164921240799478 - 0.004164921240799478 * 0.03
    assert pools_pos_val_call_4 = 9315544891212408;
        
    let (pools_pos_val_put_4) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_put_addr
    );
    // Premia - fees -> User is short, pool is long
    // 108.79470021290733 - 108.79470021290733 * 0.03
    assert pools_pos_val_put_4 = 243337593957669002910;

    // Close both positions
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    
    // Test value of pools position -> Should be zero
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

    // Open put/call long/short positions(long=1, short=0.5)
    let two = Math64x61.fromFelt(2);
    let half = Math64x61.div(one, two);

    // Calls
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr

    );

    // Puts
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    let (pools_pos_val_call_6) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_call_addr
    ); 
    // Pool is net short -> locked_capital - premia - fees
    // 0.5 - 0.0016825104937091434 - 0.0016825104937091434 * 0.03
    assert pools_pos_val_call_6 = 1148925511395203630;
        
    let (pools_pos_val_put_6) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_put_addr
    ); 
    // Pool is net short -> locked_capital - premia - fees
    // 0.5*1500 - 53.17407585832186 - 53.17407585832186 * 0.03
    assert pools_pos_val_put_6 = 1603092853688281053408;

    // Close half of all the positions
    let quarter = Math64x61.div(half, two);
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=quarter,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=quarter,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    // Test value of pools position 
    let (pools_pos_val_call_6) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_call_addr
    );
    // Locked capital - premia - fee -> User is long, pool is short
    // 0.25 - 0.0009191786794549798 - 0.0009191786794549798 * 0.03 
    assert pools_pos_val_call_6 = 574277686119216762;
        
    let (pools_pos_val_put_6) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_put_addr
    );
    // Locked capital - premia - fee -> User is long, pool is short
    // 0.25 * 1500 - 26.790869645069446 - 26.790869645069446 * 0.03
    assert pools_pos_val_put_6 = 801062322788841330820;

    // Close rest of the positions
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=quarter,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=quarter,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    // Test value of pools position -> Should be zero
    let (pools_pos_val_call_7) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_call_addr
    );
    assert pools_pos_val_call_7 = 0;
        
    let (pools_pos_val_put_7) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_put_addr
    );
    assert pools_pos_val_put_7 = 0;

    // Buy bigger chunks of pools balances
    let four = Math64x61.fromFelt(4);
    let three = Math64x61.fromFelt(3);

    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=four,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=three,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    // Test value of pools position 
    let (pools_pos_val_call_8) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_call_addr
    );
    // Locked capital - premia - fees -> User is long, pool is short
    // 4 - 0.18445432196949377 - 0.18445432196949377 * 0.03
    assert pools_pos_val_call_8 = 8785289646757188469;
        
    let (pools_pos_val_put_8) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_put_addr
    );
    // Locked capital - premia - fees -> User is long, pool is short
    // 3 * 1500 - 846.1417797601932 - 846.1417797601932 * 0.03
    assert pools_pos_val_put_8 = 8366691330568037798463;
   
    %{
        stop_warp_1()
        stop_mock_current_price_1()

        stop_warp_2 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) # Go forward in time by half a day -> 12 hours left till expiry
        stop_mock_current_price_2 = mock_call(
            ids.tmp_address, "get_spot_median", [155000000000, 8, 0, 0]  # mock current ETH price at 1550
        )
    %}

    // Test value of pools position 
    let (pools_pos_val_call_9) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_call_addr
    );
    // Locked capital - premia - fees -> User is long, pool is short
    // 4 - 0.276908397855322 - 0.276908397855322 * 0.03
    assert pools_pos_val_call_9 = 8565709524665899508;
        
    let (pools_pos_val_put_9) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_put_addr
    );
    // Locked capital - premia - fees -> User is long, pool is short
    // 3 * 1500 - 440.1255978239911 - 440.1255978239911 * 0.03
    assert pools_pos_val_put_9 = 9330987192555621765671;

    // Open short positions
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    // test value of pools position 
    let (pools_pos_val_call_10) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_call_addr
    );
    // Locked capital - premia - fees -> User is long, pool is short
    // (4 - 0.5) - 0.2000023562772017 - 0.2000023562772017 * 0.03
    assert pools_pos_val_call_10 = 7595441276148435175;
        
    let (pools_pos_val_put_10) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_put_addr
    );
    // Locked capital - premia - fees -> User is long, pool is short
    // (3 - 0.5) * 1500 - 241.56835326689273 - 241.56835326689273 * 0.03
    assert pools_pos_val_put_10 = 8073182024964791848746;

    %{
        stop_warp_2()
        stop_warp_3 = warp(1000000000 + 60*60*24 + 1, target_contract_address=ids.amm_addr) # Jump to time after maturity
        
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
    
    // Test value of pools position -> should be zero
    let (pools_pos_val_call_11) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_call_addr
    );
    assert pools_pos_val_call_11 = 0;
        
    let (pools_pos_val_put_11) = ILiquidityPool.get_value_of_pool_position(
        contract_address = amm_addr,
        lptoken_address = lpt_put_addr
    );
    assert pools_pos_val_put_11 = 0;
    
    %{
        stop_warp_3()
        stop_mock_current_price_2()
        stop_mock_terminal_price()
    %}

    return ();
}