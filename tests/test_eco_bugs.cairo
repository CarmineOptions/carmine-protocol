%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_sub, assert_uint256_le

from math64x61 import Math64x61
from openzeppelin.token.erc20.IERC20 import IERC20

from interfaces.interface_lptoken import ILPToken
from interfaces.interface_option_token import IOptionToken
from interfaces.interface_amm import IAMM

from constants import EMPIRIC_ORACLE_ADDRESS, TRADE_SIDE_LONG
from constants import get_opposite_side
from tests.itest_specs.setup import deploy_setup


@external
func setup_eco_bugs{syscall_ptr: felt*, range_check_ptr}(){

    deploy_setup();
    
    %{
    
        given(
            option_type = strategy.integers(0, 1),
            trade_side = strategy.integers(0, 1),
            option_size = strategy.integers(1, 2).map(lambda x: int(x * 10**18))
        )
        
        max_examples(30)
        
    %}
    
    return ();
}

@external
func test_eco_bugs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt,
    trade_side: felt,
    option_size: felt
) {
    alloc_locals;

    // local lpt_addr;
    local amm_addr;
    local myusd_addr;
    local myeth_addr;
    local admin_addr;
    local expiry;
    let strike_price = Math64x61.fromFelt(1500);

    let (opposite_trade_side) = get_opposite_side(trade_side);

    %{

        ids.amm_addr = context.amm_addr
        ids.myusd_addr = context.myusd_address
        ids.myeth_addr = context.myeth_address
        ids.expiry = context.expiry_0
        ids.admin_addr = context.admin_address
        
    %}

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

    local tmp_address = EMPIRIC_ORACLE_ADDRESS;
    
    %{
        stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        stop_mock_current_price = mock_call(
            ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
        )
        stop_warp_1 = warp(1000000000, target_contract_address=ids.amm_addr)
    %}

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

    // Conduct first trade 
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=option_type,
        strike_price=strike_price,
        maturity=expiry,
        option_side=trade_side,
        option_size=option_size,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        limit_total_premia=limit_total_premia,
        tx_deadline=1000000001
    );

    // Conduct second trade with opposite side
    let (_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=option_type,
        strike_price=strike_price,
        maturity=expiry,
        option_side=opposite_trade_side,
        option_size=option_size,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        limit_total_premia=opposite_limit_total_premia,
        tx_deadline=1000000001
    );

    // Get intermediate amount of myUSD on option-buyer's account
    let (admin_myUSD_balance_middle: Uint256) = IERC20.balanceOf(
        contract_address=myusd_addr,
        account=admin_addr
    );
    // Get intermediate amount of myETH in buyers account
    let (admin_myETH_balance_middle: Uint256) = IERC20.balanceOf(
        contract_address=myeth_addr,
        account=admin_addr
    );

    assert_uint256_le(admin_myETH_balance_middle, admin_myETH_balance_start);
    assert_uint256_le(admin_myUSD_balance_middle, admin_myUSD_balance_start);


    // Close first trade 
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=option_type,
        strike_price=strike_price,
        maturity=expiry,
        option_side=trade_side,
        option_size=option_size,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        limit_total_premia=opposite_limit_total_premia,
        tx_deadline=1000000001
    );

    // Close second trade with opposite side
    let (_) = IAMM.trade_close(
        contract_address=amm_addr,
        option_type=option_type,
        strike_price=strike_price,
        maturity=expiry,
        option_side=opposite_trade_side,
        option_size=option_size,
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

    assert_uint256_le(admin_myETH_balance_final, admin_myETH_balance_start);
    assert_uint256_le(admin_myUSD_balance_final, admin_myUSD_balance_start);


    return();
}

