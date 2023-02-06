%lang starknet 

from starkware.cairo.common.cairo_builtins import HashBuiltin

from math64x61 import Math64x61

from contracts.option_pricing_helpers import get_new_volatility
from tests.itest_specs.setup import deploy_setup

// @external
// func __setup__{syscall_ptr: felt*, range_check_ptr}(){

//     deploy_setup();

//     return ();
// }

@external
func test_get_new_volatility_basic{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    let hundred_64 = Math64x61.fromFelt(100);
    let one_64 = Math64x61.fromFelt(1);
    let two_64 = Math64x61.fromFelt(2);
    let half_64 = Math64x61.div(one_64, two_64);

    let strike = Math64x61.fromFelt(1000);
    let pool_bal_call = Math64x61.fromFelt(5);

    //////////////////////////////////////
    // Volatility update formula
    //
    // sigma_{trade} = (sigma_{t-1} + sigma_{t}) / 2
    // 
    // vol_denom = 1 - (Q_{t} / PS_{t}) ^ alpha
    // sigma_{t} = sigma_{t-1} * 1 / vol_denom
    //
    // Note: alpha is currently 1
    //////////////////////////////////////

    // Basic updates
    let (vol_call_long_1, trade_vol_call_long_1) = get_new_volatility(
        current_volatility = one_64,
        option_size = one_64,
        option_type = 0,
        side = 0,
        strike_price = strike,
        current_pool_balance = pool_bal_call
    );

    assert vol_call_long_1 = 2882303761517117439; // 1.25
    assert trade_vol_call_long_1 = 2594073385365405695; // 1.125

    let (vol_call_short_1, trade_vol_call_short_1) = get_new_volatility(
        current_volatility = one_64,
        option_size = one_64,
        option_type = 0,
        side = 1,
        strike_price = strike,
        current_pool_balance = pool_bal_call
    );

    assert vol_call_short_1 = 1921535841011411626; // 0.833
    assert trade_vol_call_short_1 = 2113689425112552789; // 0.916

    // Same updates, but divided into two parts  
    let (vol_call_long_2, trade_vol_call_long_2) = get_new_volatility(
        current_volatility = one_64,
        option_size = half_64,
        option_type = 0,
        side = 0,
        strike_price = strike,
        current_pool_balance = pool_bal_call
    );

    assert vol_call_long_2 = 2562047788015215501; // 1.11
    assert trade_vol_call_long_2 = 2433945398614454726; // 1.05
    

    let pool_bal_call_2 = 10376293541461622784; // 4.5 * 2**61
    let (vol_call_long_3, trade_vol_call_long_3) = get_new_volatility(
        current_volatility = vol_call_long_2,
        option_size = half_64,
        option_type = 0,
        side = 0,
        strike_price = strike,
        current_pool_balance = pool_bal_call_2
    );
    
    assert vol_call_long_3 = 2882303761517117437; // 1.25 -> same as in basic
    assert trade_vol_call_long_3 = 2722175774766166469; // 1.18 

    // Same updates, but divided into two parts  
    let (vol_call_short_2, trade_vol_call_short_2) = get_new_volatility(
        current_volatility = one_64,
        option_size = half_64,
        option_type = 0,
        side = 1,
        strike_price = strike,
        current_pool_balance = pool_bal_call
    );

    assert vol_call_short_2 = 2096220917466994501; // 0.909
    assert trade_vol_call_short_2 = 2201031963340344226; // 0.954

    let pool_bal_call_3 = 12682136550675316736; // 5.5 * 2**61
    let (vol_call_short_3, trade_vol_call_short_3) = get_new_volatility(
        current_volatility = vol_call_short_2,
        option_size = half_64,
        option_type = 0,
        side = 1,
        strike_price = strike,
        current_pool_balance = pool_bal_call_3
    );

    assert vol_call_short_3 = 1921535841011411625; // 0.83 -> same as in basic
    assert trade_vol_call_short_3 =  2008878379239203063; // 0.87

    return();
}














