%lang starknet 

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq

from math64x61 import Math64x61
from openzeppelin.token.erc20.IERC20 import IERC20

from interfaces.interface_lptoken import ILPToken
from interfaces.interface_option_token import IOptionToken
from interfaces.interface_amm import IAMM

from constants import EMPIRIC_ORACLE_ADDRESS, TRADE_SIDE_LONG
from option_pricing_helpers import get_new_volatility
from types import Option
from tests.itest_specs.setup import deploy_setup


@external
func setup_get_new_volatility{syscall_ptr: felt*, range_check_ptr}(){

    %{
        given(
            option_type = strategy.integers(0, 1),
            trade_side = strategy.integers(0, 1),
            option_size = strategy.integers(1, 100).map(lambda x: int(((x / 10) * 10**18))),
            volatility = strategy.integers(1, 100).map(lambda x: int((x / 10) * 2**61))
        )
        max_examples(100)
    %}

    return ();
}

@external
func test_get_new_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt,
    trade_side: felt,
    option_size: felt,
    volatility: felt
) {
    alloc_locals;

    local half_size;
    local pool_volatility_adjustment_speed;
    let strike = Math64x61.fromFelt(1000);

    %{
        ids.half_size = int(ids.option_size / 2)
        ids.option_size = ids.half_size * 2 # To prevent rounding errors I guess

        if ids.option_type == 0: 
            ids.pool_volatility_adjustment_speed = int(10_000 * 2**61)

        elif ids.option_type == 1: 
            ids.pool_volatility_adjustment_speed = int(10_000_000 * 2**61)

        else:
            raise ValueError(f"Unknown option type: {ids.option_type}")
   %}

    //////////////////////////////////////
    // Volatility update formula
    //
    // sigma_{trade} = (sigma_{t-1} + sigma_{t}) / 2
    // 
    // sigma_{t} = sigma_{t-1} + (trade_size / pool_volatility_adjustment_speed) -> LONG
    // sigma_{t} = sigma_{t-1} - (trade_size / pool_volatility_adjustment_speed) -> SHORT
    // 
    //////////////////////////////////////

    // Basic update
    let (desired_vol, _) = get_new_volatility(
        current_volatility = volatility,
        option_size = option_size,
        option_type = option_type,
        side = trade_side,
        strike_price = strike,
        pool_volatility_adjustment_speed = pool_volatility_adjustment_speed
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
        pool_volatility_adjustment_speed = pool_volatility_adjustment_speed
    );

    let (vol_2, _) = get_new_volatility(
        current_volatility = vol_1, // Use previous vol
        option_size = half_size,
        option_type = option_type,
        side = trade_side,
        strike_price = strike,
        pool_volatility_adjustment_speed = pool_volatility_adjustment_speed
    );  

    %{
        from math import isclose
        error_string = f"""
            Test get new vol failed for:
            option_type = {ids.option_type}, 
            side = {ids.trade_side} ,
            pool_balance = {ids.pool_volatility_adjustment_speed}, 
            size = {ids.option_size}, 
            init_vol = {ids.volatility}, 
            desired_vol = {context.desired_vol},
            final_vol = {ids.vol_2}
        """

        assert isclose(context.desired_vol, ids.vol_2, rel_tol = 0.01), error_string
    %}

    return();
}

@external
func setup_volatility_updates{syscall_ptr: felt*, range_check_ptr}(){

    deploy_setup();

    %{
    
        given(
            option_type = strategy.integers(0, 1),
            trade_side = strategy.integers(0, 1),
            # test fail sometimes for strategy below
            # option_size = strategy.integers(1, 30).map(lambda x: int((x / 10) * 10**18))
            option_size = strategy.integers(1, 2).map(lambda x: int(x * 10**18))
        )

        max_examples(30)
    %}

    return ();
}


@external
func test_volatility_updates{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt,
    trade_side: felt,
    option_size: felt
) {
    alloc_locals;

    // Present some trade, calculate how much would trader's balance be if it 
    // would be conducted all at one
    // Split the trade and make sure that the trader's balance doesn't differ too much

    local lpt_addr;
    local amm_addr;
    local myusd_addr;
    local myeth_addr;
    local admin_addr;
    local expiry;
    local opt_addr;
    local option_size_half;
    let strike_price = Math64x61.fromFelt(1500);

    %{
        ids.amm_addr = context.amm_addr
        ids.myusd_addr = context.myusd_address
        ids.myeth_addr = context.myeth_address
        ids.expiry = context.expiry_0
        ids.admin_addr = context.admin_address

        ids.option_size_half = int(ids.option_size / 2)
        ids.option_size = int(ids.option_size_half * 2) # To prevent more rounding errors i guess

        if ids.option_type == 0:
            ids.lpt_addr = context.lpt_call_addr
            if ids.trade_side == 0:
                ids.opt_addr = context.opt_long_call_addr_0
            elif ids.trade_side == 1:
                ids.opt_addr = context.opt_short_call_addr_0
            else:
                raise ValueError(f"Unknown trade side: {ids.trade_side}")
                
        elif ids.option_type == 1:
            ids.lpt_addr = context.lpt_put_addr
            if ids.trade_side == 0:
                ids.opt_addr = context.opt_long_put_addr_0
            elif ids.trade_side == 1:
                ids.opt_addr = context.opt_short_put_addr_0
            else:
                raise ValueError(f"Unknown trade side: {ids.trade_side}")

        else: 
            raise ValueError(f"Unknown option type: {ids.option_type}")

    %}

    let option_size_uint: Uint256 = Uint256(
        option_size,
        0
    );

    // Test starting amount of myUSD on option-buyer's account
    let (admin_myUSD_balance_start: Uint256) = IERC20.balanceOf(
        contract_address=myusd_addr,
        account=admin_addr
    );
    // Get starting amount of myETH in buyers account
    let (admin_myETH_balance_start: Uint256) = IERC20.balanceOf(
        contract_address=myeth_addr,
        account=admin_addr
    );

    // Get premia for whole trade
    let option_struct = Option(
        option_side = trade_side,
        maturity = expiry,
        strike_price = strike_price,
        quote_token_address = myusd_addr,
        base_token_address = myeth_addr,
        option_type = option_type,
    );

    local tmp_address = EMPIRIC_ORACLE_ADDRESS;
    %{
        stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        stop_mock_current_price = mock_call(
            ids.tmp_address, "get_spot_median", [140000000000, 8, 1000000000, 0]  # mock current ETH price at 1400
        )
        stop_warp_1 = warp(1000000000, target_contract_address=ids.amm_addr)
    %}

    let (prem_no_fee, total_premia_including_fees) = IAMM.get_total_premia(
        amm_addr,
        option_struct,
        lpt_addr,
        option_size_uint,
        0
    );

    // Effectively switching off the slippage
    local limit_total_premia;
    local opposite_limit_total_premia;
    if (trade_side == TRADE_SIDE_LONG) {
        tempvar limit_total_premia=230584300921369400000000000000000000;
        tempvar opposite_limit_total_premia=1;
    } else {
        tempvar limit_total_premia=1;
        tempvar opposite_limit_total_premia=230584300921369400000000000000000;
    }

    // Conduct first trade of half size
    let (prem_1) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=option_type,
        strike_price=strike_price,
        maturity=expiry,
        option_side=trade_side,
        option_size=option_size_half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        limit_total_premia=limit_total_premia,
        tx_deadline=1000000001
    );
    // Conduct second trade of half size
    let (prem_2) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=option_type,
        strike_price=strike_price,
        maturity=expiry,
        option_side=trade_side,
        option_size=option_size_half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        limit_total_premia=limit_total_premia,
        tx_deadline=1000000001
    );

    // Get final amount of myUSD on option-buyer's account
    let (admin_myUSD_balance_final: Uint256) = IERC20.balanceOf(
        contract_address=myusd_addr,
        account=admin_addr
    );
    // Get final amount of myETH in buyers account
    let (admin_myETH_balance_final: Uint256) = IERC20.balanceOf(
        contract_address=myeth_addr,
        account=admin_addr
    );

    %{
        if ids.option_type == 0:
            if ids.trade_side == 0:
                desired_balance = (
                    int(ids.admin_myETH_balance_start.low) - 
                    int((ids.total_premia_including_fees / 2**61) * 10**18)
                )

            elif ids.trade_side == 1:
                desired_balance = (
                    int(ids.admin_myETH_balance_start.low) + 
                    int((ids.total_premia_including_fees / 2**61) * 10**18) - 
                    ids.option_size
                )

        elif ids.option_type == 1:
            if ids.trade_side == 0:
                desired_balance = (
                    int(ids.admin_myUSD_balance_start.low) - 
                    int((ids.total_premia_including_fees / 2**61) * 10**6)
                )

            elif ids.trade_side == 1:
                desired_balance = (
                    int(ids.admin_myUSD_balance_start.low) +
                    int((ids.total_premia_including_fees / 2**61) * 10**6) -
                    int(((ids.option_size / 10**18) * (ids.strike_price / 2**61)) * 10**6)
                )



        from math import isclose
        error_string = f"""
            Test vol updates failed for:
            option_type = {ids.option_type}, 
            side = {ids.trade_side} ,
            size = {ids.option_size}, 
            desired_balance = {desired_balance},
            final_balance_USD = {ids.admin_myUSD_balance_final.low}
            final_balance_ETH = {ids.admin_myETH_balance_final.low}
        """

        if ids.option_type == 0:
            assert isclose(desired_balance, ids.admin_myETH_balance_final.low, rel_tol = 0.01), error_string
        if ids.option_type == 1:
            # The higher rel_tol is caused by the extreme proportion of trade size to liquidity pool
            assert isclose(desired_balance, ids.admin_myUSD_balance_final.low, rel_tol = 0.1), error_string
    %}
    
    return();
}

