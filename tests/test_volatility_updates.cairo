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
func setup_get_new_volatility_basic{syscall_ptr: felt*, range_check_ptr}(){

    %{
        given(
            option_type = strategy.integers(0, 1),
            trade_side = strategy.integers(0, 1),
            option_size = strategy.integers(1, 100).map(lambda x: int(((x / 10) * 10**18))),
           _pool_balance = strategy.integers(200, 1000).map(lambda x: int((x / 10) * 2**61)),
            volatility = strategy.integers(1, 100).map(lambda x: int((x / 10) * 2**61))
        )
        max_examples(100)
    %}

    return ();
}
@external
func test_get_new_volatility_basic{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt,
    trade_side: felt,
    option_size: felt,
    _pool_balance: felt,
    volatility: felt
) {
    alloc_locals;

    local half_size;
    local pool_balance;
    let strike = Math64x61.fromFelt(1000);

    %{
        ids.half_size = int(ids.option_size / 2)
        ids.option_size = ids.half_size * 2 # To prevent rounding errors I guess

        if ids.option_type == 0: 
            ids.pool_balance = ids._pool_balance
        elif ids.option_type == 1: 
            ids.pool_balance = int(ids._pool_balance * (ids.strike / 2**61))
        else:
            raise ValueError(f"Unknown option type: {ids.option_type}")
   %}

    //////////////////////////////////////
    // Volatility update formula
    //
    // sigma_{trade} = (sigma_{t-1} + sigma_{t}) / 2
    // 
    // vol_denom = 1 - (Q_{t} / PS_{t}) ^ alpha
    // sigma_{t} = sigma_{t-1} * 1 / vol_denom
    //
    // Note: alpha is 1
    //////////////////////////////////////

    // Basic update
    let (desired_vol, _) = get_new_volatility(
        current_volatility = volatility,
        option_size = option_size,
        option_type = option_type,
        side = trade_side,
        strike_price = strike,
        current_pool_balance = pool_balance
    );

    %{
        # Save the value as the reference gets revoked
        context.desired_vol = ids.desired_vol
    %}

    // Same update, but divided into two parts  
    let (vol_1, _) = get_new_volatility(
        current_volatility = volatility,
        option_size = half_size,
        option_type = option_type,
        side = trade_side,
        strike_price = strike,
        current_pool_balance = pool_balance
    );

    // Adjust pool balance 
    local pool_balance_2;
    %{  
        if ids.trade_side == 0:
            if ids.option_type == 0:
                ids.pool_balance_2 = ids.pool_balance - ids.half_size
            elif ids.option_type == 1:
                ids.pool_balance_2 = ids.pool_balance - int(ids.half_size * (ids.strike / 2**61))
        elif ids.trade_side == 1:
            ids.pool_balance_2 = ids.pool_balance
        else:
            raise ValueError(f"Unknown trade side: {ids.trade_side}")
    %}

    let (vol_2, _) = get_new_volatility(
        current_volatility = vol_1, // Use previous vol
        option_size = half_size,
        option_type = option_type,
        side = trade_side,
        strike_price = strike,
        current_pool_balance = pool_balance_2
    );  

    %{
        from math import isclose
        error_string = f"""
            Test vol updates basic failed for:
            option_type = {ids.option_type}, 
            side = {ids.trade_side} ,
            pool_balance = {ids.pool_balance}, 
            size = {ids.option_size}, 
            init_vol = {ids.volatility}, 
            desired_vol = {context.desired_vol},
            final_vol = {ids.vol_2}
        """

        assert isclose(context.desired_vol, ids.vol_2, rel_tol = 0.01), error_string
    %}

    return();
}


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














