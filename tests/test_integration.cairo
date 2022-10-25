%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool
from interface_amm import IAMM
from types import Math64x61_
from constants import EMPIRIC_ORACLE_ADDRESS

from openzeppelin.token.erc20.IERC20 import IERC20
from math64x61 import Math64x61

from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_eq


@external
func __setup__{syscall_ptr: felt*, range_check_ptr}(){
    // Makefile takes care of generation of build/ammcontract.cairo. Proxy is mocked.
    // TODO use dict notation in contract constructors

    alloc_locals;

    tempvar lpt_addr;
    tempvar opt_long_call_addr;
    tempvar amm_addr;
    tempvar myusd_addr;
    tempvar myeth_addr;
    tempvar admin_addr;

    tempvar expiry;
    tempvar side_long;
    tempvar optype_call;
    let strike_price = Math64x61.fromFelt(1500);
    %{
        from datetime import datetime, timedelta
        admin_address = 123456
        context.admin_address = admin_address
        context.amm_addr = deploy_contract("./build/ammcontract.cairo").contract_address
        # We mock ETH and USD, because that's the simplest way to get
        # mints 10 ETH to admin address
        context.myeth_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [1, 1, 18, 10 * 10**18, 0, admin_address, admin_address]).contract_address
        # usdc has 6 decimals
        # mints 10k myUSD to admin address
        context.myusd_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [2, 2, 6, 10000 * 10**6, 0, admin_address, admin_address]).contract_address

        # todo find out whether dict notation in attr is required to pass strings
        context.lpt0_addr = deploy_contract("./contracts/lptoken.cairo", [111, 11, 18, 0, 0, admin_address, context.amm_addr]).contract_address # here we can use strings and not only felts yay
        expiry = (datetime.now() + timedelta(hours=24))
        expiry = expiry - timedelta(  # floor expiry to whole hour
            minutes=expiry.minute,
            seconds=expiry.second,
            microseconds=expiry.microsecond
        )
        expiry = int(expiry.timestamp())
        context.expiry_0 = expiry
        LONG = 0
        side_long = LONG
        CALL = 0
        optype_call = CALL

        context.opt0_addr = deploy_contract("./contracts/option_token.cairo", [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.myeth_address, optype_call, ids.strike_price, expiry, side_long]).contract_address
        #stop_prank_amm = start_prank(admin_address, context.amm_addr)  # sets caller addr to admin addr
        #stop_prank_lpt0 = start_prank(admin_address, context.lpt0_addr)
        #stop_prank_opt0 = start_prank(admin_address, context.opt0_addr)
        #stop_prank_myeth = start_prank(admin_address, context.myeth_address)
        #stop_prank_myusd = start_prank(admin_address, context.myusd_address)

        ids.expiry = expiry
        ids.optype_call = optype_call
        ids.side_long = side_long

        ids.lpt_addr = context.lpt0_addr
        ids.opt_long_call_addr = context.opt0_addr
        ids.amm_addr = context.amm_addr
        ids.myusd_addr = context.myusd_address
        ids.myeth_addr = context.myeth_address
        ids.admin_addr = context.admin_address
    %}

    // Sanity checks on minted tokens
    
    let (baleth) = IERC20.balanceOf(contract_address=myeth_addr, account=admin_addr);
    assert baleth.low = 10000000000000000000;
    let (balusd) = IERC20.balanceOf(contract_address=myusd_addr, account=admin_addr);
    assert balusd.low = 10000000000;

    // Add LPToken

    ILiquidityPool.add_lptoken(contract_address=amm_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=0, lptoken_address=lpt_addr);

    // Approve myUSD and myETH for use by amm

    let max_127bit_number = 0x80000000000000000000000000000000;
    let approve_amt = Uint256(low = max_127bit_number, high = max_127bit_number);
    let million = Uint256(low = 1000000, high = 0);
    %{
        stop_prank_myeth = start_prank(context.admin_address, context.myeth_address)
    %}
    IERC20.approve(contract_address=myeth_addr, spender=amm_addr, amount=approve_amt);
    let (res: Uint256) = IERC20.allowance(contract_address=myeth_addr, owner=admin_addr, spender=amm_addr);
    let (a: felt) = uint256_le(res, approve_amt);
    assert a = 1;
    %{
        stop_prank_myeth()
        stop_prank_myusd = start_prank(context.admin_address, context.myusd_address)
    %}
    IERC20.approve(contract_address=myusd_addr, spender=amm_addr, amount=approve_amt);

    // Deposit 5 ETH liquidity

    %{
        stop_prank_myusd()
        stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
    %}
    let five_eth = Uint256(low = 5000000000000000000, high = 0);
    ILiquidityPool.deposit_liquidity(contract_address=amm_addr, pooled_token_addr=myeth_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=0, amount=five_eth);
    let (bal_lpt: Uint256) = ILPToken.balanceOf(contract_address=lpt_addr, account=admin_addr);
    assert bal_lpt.low = 5000000000000000000;

    // Add option

    let one_m64x61 = Math64x61.fromFelt(1);
    ILiquidityPool.add_option(
        contract_address=amm_addr,
        option_side=side_long,
        maturity=expiry,
        strike_price=strike_price,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        option_type=optype_call,
        lptoken_address=lpt_addr,
        option_token_address_=opt_long_call_addr,
        initial_volatility=one_m64x61
    );

    %{
        stop_prank_amm()
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
func test_trade_open{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;

    tempvar lpt_addr;
    tempvar opt_long_call_addr;
    tempvar amm_addr;
    tempvar myusd_addr;
    tempvar myeth_addr;
    tempvar admin_addr;

    tempvar expiry;
    %{

        ids.lpt_addr = context.lpt0_addr
        ids.opt_long_call_addr = context.opt0_addr
        ids.amm_addr = context.amm_addr
        ids.myusd_addr = context.myusd_address
        ids.myeth_addr = context.myeth_address
        ids.admin_addr = context.admin_address

        ids.expiry = context.expiry_0
    %}

    let strike_price = Math64x61.fromFelt(1500);
    let one = Math64x61.fromFelt(1);

    %{
        stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        stop_mock = mock_call(
            ids.EMPIRIC_ORACLE_ADDRESS, "get_value", [1400000000000000000000, 18, 0, 0]  # mock current ETH price at 1400
        )
    %}
    let (premia: Math64x61_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    assert premia = 21776214599888895; // approx 0.009 ETH, approximately 12 USD at fixed prices, checks out, maybe a bit too high?

    %{
        # optional, but included for completeness and extensibility
        stop_prank_amm()
        stop_mock()
    %}
    return ();
}

// TODO test_withdraw_liquidity, settle, ...

// @external
// func test_minimal_example{syscall_ptr: felt*, range_check_ptr}() {
//     alloc_locals;

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
//
//     %{
//     stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
//     %}
//     return ();
// }
