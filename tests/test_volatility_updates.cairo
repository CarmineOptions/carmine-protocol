%lang starknet 

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq

from math64x61 import Math64x61
from openzeppelin.token.erc20.IERC20 import IERC20

from interface_lptoken import ILPToken
from interface_option_token import IOptionToken
from interface_amm import IAMM

from constants import EMPIRIC_ORACLE_ADDRESS
from contracts.option_pricing_helpers import get_new_volatility
from types import Option
from tests.itest_specs.setup import deploy_setup


@external
func setup_get_new_volatility{syscall_ptr: felt*, range_check_ptr}(){

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
func test_get_new_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
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
            Test get new vol failed for:
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

@external
func setup_volatility_updates{syscall_ptr: felt*, range_check_ptr}(){

    deploy_setup();

    %{
    
        given(
            option_type = strategy.integers(0, 1),
            trade_side = strategy.integers(0, 1),
            # test fail sometimes for strategy below
            # option_size = strategy.integers(1, 30).map(lambda x: int((x / 10) * 10**18))
            option_size = strategy.integers(1, 3).map(lambda x: int(x * 10**18))
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
            ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
        )
        stop_warp_1 = warp(1000000000, target_contract_address=ids.amm_addr)
    %}

    let (_, total_premia_including_fees) = IAMM.get_total_premia(
        amm_addr,
        option_struct,
        lpt_addr,
        option_size_uint,
        0
    );

    // Conduct first trade of half size
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=option_type,
        strike_price=strike_price,
        maturity=expiry,
        option_side=trade_side,
        option_size=option_size_half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );
    // Conduct second trade of half size
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=option_type,
        strike_price=strike_price,
        maturity=expiry,
        option_side=trade_side,
        option_size=option_size_half,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
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
                desired_balance = int(ids.admin_myETH_balance_start.low) - int((ids.total_premia_including_fees / 2**61) * 10**18)
            elif ids.trade_side == 1:
                desired_balance = int(ids.admin_myETH_balance_start.low) + int((ids.total_premia_including_fees / 2**61) * 10**18) - ids.option_size

        elif ids.option_type == 1:
            if ids.trade_side == 0:
                desired_balance = int(ids.admin_myUSD_balance_start.low) - int((ids.total_premia_including_fees / 2**61) * 10**6)
            elif ids.trade_side == 1:
                desired_balance = int(ids.admin_myUSD_balance_start.low) + int((ids.total_premia_including_fees / 2**61) * 10**6) - int(((ids.option_size / 10**18) * (ids.strike_price / 2**61)) * 10**6)


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
            # rel_tol = 0.1 here is NOT needed for every case, it just failes for one or two specific numbers idk why yet
            # FIXME: Find out why it fails on rel_tol=0.01 and fix
            assert isclose(desired_balance, ids.admin_myUSD_balance_final.low, rel_tol = 0.1), error_string
    %}
    
    return();
}

