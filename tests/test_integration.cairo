%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool
from interface_option_token import IOptionToken
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

    tempvar lpt_call_addr;
    tempvar lpt_put_addr;
    tempvar opt_long_call_addr;
    tempvar opt_short_call_addr;
    tempvar opt_long_put_addr;
    tempvar opt_short_put_addr;
    tempvar amm_addr;
    tempvar myusd_addr;
    tempvar myeth_addr;
    tempvar admin_addr;

    tempvar expiry;
    tempvar side_long;
    tempvar side_short;
    tempvar optype_call;
    tempvar optype_put;
    let strike_price = Math64x61.fromFelt(1500);

    // Fixing current time to "easily rememberable" number
    %{ warp(1000000000) %}

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
        context.lpt_call_addr = deploy_contract("./contracts/lptoken.cairo", [111, 11, 18, 0, 0, admin_address, context.amm_addr]).contract_address # here we can use strings and not only felts yay
        context.lpt_put_addr = deploy_contract("./contracts/lptoken.cairo", [112, 12, 18, 0, 0, admin_address, context.amm_addr]).contract_address # here we can use strings and not only felts yay

        # current time plus 24 hours
        expiry = int(1000000000 + 60*60*24)
        context.expiry_0 = expiry
        LONG = 0
        side_long = LONG
        SHORT = 1
        side_short = SHORT
        CALL = 0
        optype_call = CALL
        PUT = 1
        optype_put = PUT

        context.opt_long_call_addr_0 = deploy_contract("./contracts/option_token.cairo", [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.myeth_address, optype_call, ids.strike_price, expiry, side_long]).contract_address
        context.opt_short_call_addr_0 = deploy_contract("./contracts/option_token.cairo", [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.myeth_address, optype_call, ids.strike_price, expiry, side_short]).contract_address
        context.opt_long_put_addr_0 = deploy_contract("./contracts/option_token.cairo", [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.myeth_address, optype_put, ids.strike_price, expiry, side_long]).contract_address
        context.opt_short_put_addr_0 = deploy_contract("./contracts/option_token.cairo", [1234, 14, 18, 0, 0, admin_address, context.amm_addr, context.myusd_address, context.myeth_address, optype_put, ids.strike_price, expiry, side_short]).contract_address
        #stop_prank_amm = start_prank(admin_address, context.amm_addr)  # sets caller addr to admin addr
        #stop_prank_lpt0 = start_prank(admin_address, context.lpt_call_addr)
        #stop_prank_opt0 = start_prank(admin_address, context.opt_long_call_addr_0)
        #stop_prank_myeth = start_prank(admin_address, context.myeth_address)
        #stop_prank_myusd = start_prank(admin_address, context.myusd_address)

        ids.expiry = expiry
        ids.optype_call = optype_call
        ids.optype_put = optype_put
        ids.side_long = side_long
        ids.side_short = side_short

        ids.lpt_call_addr = context.lpt_call_addr
        ids.lpt_put_addr = context.lpt_put_addr
        ids.opt_long_call_addr = context.opt_long_call_addr_0
        ids.opt_short_call_addr = context.opt_short_call_addr_0
        ids.opt_long_put_addr = context.opt_long_put_addr_0
        ids.opt_short_put_addr = context.opt_short_put_addr_0
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

    ILiquidityPool.add_lptoken(contract_address=amm_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=0, lptoken_address=lpt_call_addr);
    ILiquidityPool.add_lptoken(contract_address=amm_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=1, lptoken_address=lpt_put_addr);

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
    let (bal_eth_lpt: Uint256) = ILPToken.balanceOf(contract_address=lpt_call_addr, account=admin_addr);
    assert bal_eth_lpt.low = 5000000000000000000;

    // Deposit 5_000 USD liquidity

    let five_thousand_usd = Uint256(low = 5000000000, high = 0);
    ILiquidityPool.deposit_liquidity(contract_address=amm_addr, pooled_token_addr=myusd_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=1, amount=five_thousand_usd);
    // FIXME lpt_call_addr should be lpt_put_addr
    let (bal_usd_lpt: Uint256) = ILPToken.balanceOf(contract_address=lpt_put_addr, account=admin_addr);
    assert bal_usd_lpt.low = 5000000000;

    // Add option
    // FIXME: add opt_short_call, opt_long_put, opt_short_put

    let one_m64x61 = Math64x61.fromFelt(1);
    // Add long call option
    ILiquidityPool.add_option(
        contract_address=amm_addr,
        option_side=side_long,
        maturity=expiry,
        strike_price=strike_price,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        option_type=optype_call,
        lptoken_address=lpt_call_addr,
        option_token_address_=opt_long_call_addr,
        initial_volatility=one_m64x61
    );
    // Add short call option
    ILiquidityPool.add_option(
        contract_address=amm_addr,
        option_side=side_short,
        maturity=expiry,
        strike_price=strike_price,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        option_type=optype_call,
        lptoken_address=lpt_call_addr,
        option_token_address_=opt_short_call_addr,
        initial_volatility=one_m64x61
    );
    // Add long put option
    ILiquidityPool.add_option(
        contract_address=amm_addr,
        option_side=side_long,
        maturity=expiry,
        strike_price=strike_price,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        option_type=optype_put,
        lptoken_address=lpt_put_addr,
        option_token_address_=opt_long_put_addr,
        initial_volatility=one_m64x61
    );
    // Add short put option
    ILiquidityPool.add_option(
        contract_address=amm_addr,
        option_side=side_short,
        maturity=expiry,
        strike_price=strike_price,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        option_type=optype_put,
        lptoken_address=lpt_put_addr,
        option_token_address_=opt_short_put_addr,
        initial_volatility=one_m64x61
    );

    %{
        stop_prank_amm()
    %}
    return ();
}

@external
func test_option_attrs{syscall_ptr: felt*, range_check_ptr}() {
    tempvar lpt_call_addr;
    tempvar lpt_put_addr;
    %{
        ids.lpt_call_addr = context.lpt_call_addr
        ids.lpt_put_addr = context.lpt_put_addr
    %}

    let (symbol_call) = ILPToken.symbol(contract_address=lpt_call_addr);
    assert symbol_call = 11;
    let (name_call) = ILPToken.name(contract_address=lpt_call_addr);
    assert name_call = 111;

    let (symbol_put) = ILPToken.symbol(contract_address=lpt_put_addr);
    assert symbol_put = 12;
    let (name_put) = ILPToken.name(contract_address=lpt_put_addr);
    assert name_put = 112;
    return ();
}

@external
func test_lpt_attrs{syscall_ptr: felt*, range_check_ptr}() {
    tempvar opt_long_call_addr;
    tempvar opt_short_call_addr;
    tempvar opt_long_put_addr;
    tempvar opt_short_put_addr;
    tempvar base_addr;
    tempvar quote_addr;
    %{
        ids.opt_long_call_addr = context.opt_long_call_addr_0
        ids.opt_short_call_addr = context.opt_short_call_addr_0
        ids.opt_long_put_addr = context.opt_long_put_addr_0
        ids.opt_short_put_addr = context.opt_short_put_addr_0
        ids.base_addr = context.myeth_address
        ids.quote_addr = context.myusd_address
    %}

    let (quote_address_call_long) = IOptionToken.quote_token_address(contract_address=opt_long_call_addr);
    assert quote_address_call_long = quote_addr;
    let (base_address_call_long) = IOptionToken.base_token_address(contract_address=opt_long_call_addr);
    assert base_address_call_long = base_addr;
    let (option_type_call_long) = IOptionToken.option_type(contract_address=opt_long_call_addr);
    assert option_type_call_long = 0;

    let (quote_address_call_short) = IOptionToken.quote_token_address(contract_address=opt_short_call_addr);
    assert quote_address_call_short = quote_addr;
    let (base_address_call_short) = IOptionToken.base_token_address(contract_address=opt_short_call_addr);
    assert base_address_call_short = base_addr;
    let (option_type_call_short) = IOptionToken.option_type(contract_address=opt_short_call_addr);
    assert option_type_call_short = 0;

    let (quote_address_put_long) = IOptionToken.quote_token_address(contract_address=opt_long_put_addr);
    assert quote_address_put_long = quote_addr;
    let (base_address_put_long) = IOptionToken.base_token_address(contract_address=opt_long_put_addr);
    assert base_address_put_long = base_addr;
    let (option_type_put_long) = IOptionToken.option_type(contract_address=opt_long_put_addr);
    assert option_type_put_long = 1;

    let (quote_address_put_short) = IOptionToken.quote_token_address(contract_address=opt_short_put_addr);
    assert quote_address_put_short = quote_addr;
    let (base_address_put_short) = IOptionToken.base_token_address(contract_address=opt_short_put_addr);
    assert base_address_put_short = base_addr;
    let (option_type_put_short) = IOptionToken.option_type(contract_address=opt_short_put_addr);
    assert option_type_put_short = 1;

    return ();
}


@external
func test_trade_open{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;

    // 12 hours after listing, 12 hours before expir
    %{ warp(1000000000 + 60*60*12) %}

    tempvar lpt_call_addr;
    tempvar opt_long_call_addr;
    tempvar amm_addr;
    tempvar myusd_addr;
    tempvar myeth_addr;
    tempvar admin_addr;

    tempvar expiry;
    %{
        ids.lpt_call_addr = context.lpt_call_addr
        ids.opt_long_call_addr = context.opt_long_call_addr_0
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

    assert premia = 10643675488399466; // approx 0.0046 ETH, which is cca .2% of the option size

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

//     tempvar lpt_call_addr;
//     tempvar amm_addr;
//     tempvar myusd_addr;
//     tempvar myeth_addr;
//     tempvar admin_addr;
//     %{
//     ids.lpt_call_addr = context.lpt_call_addr
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
