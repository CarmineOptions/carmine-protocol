%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool

from openzeppelin.token.erc20.IERC20 import IERC20

from starkware.cairo.common.uint256 import Uint256

@external
func __setup__() {
    // Makefile takes care of generation of build/ammcontract.cairo. Proxy is mocked.
    %{
    admin_address = 123456
    context.admin_address = admin_address
    context.amm_addr = deploy_contract("./build/ammcontract.cairo").contract_address 
    # todo find out whether dict notation in attr is required to pass strings
    context.lpt0_addr = deploy_contract("./contracts/lptoken.cairo", [111, 11, 18, 0, 0, admin_address, context.amm_addr]).contract_address # here we can use strings and not only felts yay
    # We mock ETH and USD, because that's the simplest way to get 
    context.myeth_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [1, 1, 18, 1000000, 0, admin_address, admin_address]).contract_address
    # usdc has 6 decimals
    context.myusd_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [2, 2, 6, 100000000, 0, admin_address, admin_address]).contract_address
    stop_prank_amm = start_prank(admin_address, context.amm_addr)  # sets caller addr to admin addr
    stop_prank_lpt0 = start_prank(admin_address, context.lpt0_addr)  # sets caller addr to admin addr
    %}
    return ();
}

@external
func test_lpt_attrs{syscall_ptr: felt*, range_check_ptr}() {
    tempvar lpt_addr;
    %{
    ids.lpt_addr = context.lpt0_addr
    %}
    let (symbol) = ILPToken.symbol(contract_address=lpt_addr);
    assert symbol = 11;
    let (name) = ILPToken.name(contract_address=lpt_addr);
    assert name = 111;
    return ();
}

@external
func test_integration{syscall_ptr: felt*, range_check_ptr}() {
    tempvar lpt_addr;
    tempvar amm_addr;
    tempvar myusd_addr;
    tempvar myeth_addr;
    tempvar admin_addr;
    %{
    ids.lpt_addr = context.lpt0_addr
    ids.amm_addr = context.amm_addr
    ids.myusd_addr = context.myusd_address
    ids.myeth_addr = context.myeth_address
    ids.admin_addr = context.admin_address
    %}
    ILiquidityPool.add_lptoken(contract_address=amm_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=0, lptoken_address=lpt_addr);
    let bal = ILPToken.balanceOf(contract_address=lpt_addr, account=123456);
    assert bal[0].low = 0; // [0] bc Member 'low' does not appear in definition of tuple type '(balance: starkware.cairo.common.uint256.Uint256)' ??????????

    // Here we check that the admin received 10^6 wei and 100 usd (usdc has 6 decimals)
    let baleth = ILPToken.balanceOf(contract_address=myeth_addr, account=admin_addr);
    assert baleth[0].low = 1000000;
    let balusd = ILPToken.balanceOf(contract_address=myusd_addr, account=admin_addr);
    assert balusd[0].low = 100000000;


    let max_127bit_number = 0x10000000000000000000000000000000;
    let approve_amt = Uint256(low = max_127bit_number, high = max_127bit_number);
    let thousand = Uint256(low = 1000, high = 0);
    IERC20.approve(contract_address=myeth_addr, spender=amm_addr, amount=thousand);
    IERC20.approve(contract_address=myusd_addr, spender=amm_addr, amount=thousand);
    %{ expect_revert(error_message="insufficient allowance") %}
    ILiquidityPool.deposit_liquidity(contract_address=amm_addr, pooled_token_addr=myeth_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=0, amount=thousand);
    let bal_lpt = ILPToken.balanceOf(contract_address=lpt_addr, account=admin_addr);
    assert bal_lpt[0] = approve_amt;
    return ();
}

// @external
// func test_next{syscall_ptr: felt*, range_check_ptr}() {
//     tempvar lpt_addr;
//     tempvar amm_addr;
//     tempvar myusd_addr;
//     tempvar myeth_addr;
//     tempvar admin_addr;
//     %{
//     ids.lpt_addr = context.lpt0_addr
//     ids.amm_addr = context.amm_addr
//     ids.myusd_addr = context.myusd_address
//     ids.myeth_addr = context.myeth_address
//     ids.admin_addr = context.admin_address
//     %}
//     return ();
// }
