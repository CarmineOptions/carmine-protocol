%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool

@external
func __setup__() {
    // Makefile takes care of generation of build/ammcontract.cairo
    // doesn't use proxy at all
    %{ 
    admin_address = 123456
    context.amm_addr = deploy_contract("./build/ammcontract.cairo").contract_address 
    # todo find out whether dict notation in attr is required to pass strings
    context.lpt0_addr = deploy_contract("./contracts/lptoken.cairo", [111, 11, 18, 0, 0, admin_address, context.amm_addr]).contract_address # here we can use strings and not only felts yay
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

//@external //WIP
func test_add_lptoken{syscall_ptr: felt*, range_check_ptr}() {
    tempvar lpt_addr;
    tempvar amm_addr;
    %{
    ids.lpt_addr = context.lpt0_addr
    ids.amm_addr = context.amm_addr
    %}
    let eth_addr = 0x62230ea046a9a5fbc261ac77d03c8d41e5d442db2284587570ab46455fd2488;
    ILiquidityPool.add_lptoken(contract_address=lpt_addr, quote_token_address=5678, base_token_address=eth_addr, option_type=0, lptoken_address=lpt_addr);
    // WIP
    return ();
}
