%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool
from interface_option_token import IOptionToken
from interface_amm import IAMM
from types import Math64x61_
from constants import EMPIRIC_ORACLE_ADDRESS
from build.ammcontract import fromUint256, toUint256

from openzeppelin.token.erc20.IERC20 import IERC20
from math64x61 import Math64x61

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_eq
from starkware.cairo.common.math import assert_le
from starkware.starknet.common.syscalls import get_block_timestamp


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

    let hundred_m64x61 = Math64x61.fromFelt(100);
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
        initial_volatility=hundred_m64x61
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
        initial_volatility=hundred_m64x61
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
        initial_volatility=hundred_m64x61
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
        initial_volatility=hundred_m64x61
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
    %{ warp(1000000000 + 60*60*12, target_contract_address = context.amm_addr) %}

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

    // First trade, LONG CALL
    let (premia_long_call: Math64x61_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    assert premia_long_call = 2020558154346487; // approx 0.00087 ETH, or 1.22 USD 

    // Second trade, LONG SHORT
    let (premia_short_call: Math64x61_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=0,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    assert premia_short_call = 2020760452941187; // approx the same as before, but slightly higher, since vol. was increased 
                                                 // with previous trade
    // Second trade, PUT LONG
    let (premia_long_put: Math64x61_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    assert premia_long_put = 234655350073966452800;
    
    // Second trade, PUT SHORT
    let (premia_short_put: Math64x61_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=1,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    assert premia_short_put = 234722763583872553300;
    %{
        # optional, but included for completeness and extensibility
        stop_prank_amm()
        stop_mock()
    %}
    return ();
}


@external
func test_withdraw_liquidity{syscall_ptr: felt*, range_check_ptr}() {
    // test withdraw half of the liquidity that was originally deposited (from both pools)
    alloc_locals;

    tempvar lpt_call_addr;
    tempvar lpt_put_addr;
    tempvar amm_addr;
    tempvar myusd_addr;
    tempvar myeth_addr;
    tempvar admin_addr;
    %{
        ids.lpt_call_addr = context.lpt_call_addr
        ids.lpt_put_addr = context.lpt_put_addr
        ids.amm_addr = context.amm_addr
        ids.myusd_addr = context.myusd_address
        ids.myeth_addr = context.myeth_address
        ids.admin_addr = context.admin_address
    %}

    %{
        stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
    %}

    let (bal_eth_lpt: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_call_addr,
        account=admin_addr
    );
    assert bal_eth_lpt.low = 5000000000000000000;

    let (bal_usd_lpt: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_put_addr,
        account=admin_addr
    );
    assert bal_usd_lpt.low = 5000000000;

    let (call_pool_unlocked_capital) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_unlocked_capital = 11529215046068469760;

    let (put_pool_unlocked_capital) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_unlocked_capital = 11529215046068469760000;

    let two_and_half_eth = Uint256(low = 2500000000000000000, high = 0);
    IAMM.withdraw_liquidity(
        contract_address=amm_addr,
        pooled_token_addr=myeth_addr,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        option_type=0,
        lp_token_amount=two_and_half_eth
    );

    let two_and_half_thousand_usd = Uint256(low = 2500000000, high = 0);
    IAMM.withdraw_liquidity(
        contract_address=amm_addr,
        pooled_token_addr=myusd_addr,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        option_type=1,
        lp_token_amount=two_and_half_thousand_usd
    );

    let (bal_eth_lpt_after: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_call_addr,
        account=admin_addr
    );
    assert bal_eth_lpt_after.low = 2500000000000000000;

    let (bal_usd_lpt_after: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_put_addr,
        account=admin_addr
    );
    assert bal_usd_lpt_after.low = 2500000000;

    let (call_pool_unlocked_capital_after) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_unlocked_capital_after = 5764607523034234880;

    let (put_pool_unlocked_capital_after) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_unlocked_capital_after = 5764607523034234880000;

    %{
        # optional, but included for completeness and extensibility
        stop_prank_amm()
    %}
    return ();
}


@external
func test_minimal_round_trip_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test
    // -> buy call option
    // -> withdraw half of the liquidity that was originally deposited from call pool
    alloc_locals;

    tempvar lpt_call_addr;
    tempvar lpt_put_addr;
    tempvar amm_addr;
    tempvar myusd_addr;
    tempvar myeth_addr;
    tempvar admin_addr;
    tempvar expiry;
    tempvar opt_long_call_addr;
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

    %{
        stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        stop_mock_oracle_1 = mock_call(
            ids.EMPIRIC_ORACLE_ADDRESS, "get_value", [1400000000000000000000, 18, 0, 0]  # mock current ETH price at 1400
        )
    %}

    // Test initial balance of lp tokens in the account
    let (bal_eth_lpt_0: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_call_addr,
        account=admin_addr
    );
    assert bal_eth_lpt_0.low = 5000000000000000000;

    let (bal_usd_lpt_0: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_put_addr,
        account=admin_addr
    );
    assert bal_usd_lpt_0.low = 5000000000;

    // Test unlocked capital in the pools
    let (call_pool_unlocked_capital_0) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_unlocked_capital_0 = 11529215046068469760;

    let (put_pool_unlocked_capital_0) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_unlocked_capital_0 = 11529215046068469760000;

    // Test initial balance of option tokens in the account
    let (bal_opt_long_call_tokens_0: Uint256) = ILPToken.balanceOf(
        contract_address=opt_long_call_addr,
        account=admin_addr
    );
    assert bal_opt_long_call_tokens_0.low = 0;

    ///////////////////////////////////////////////////
    // BUY THE CALL OPTION

    %{ stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) %}

    let strike_price = Math64x61.fromFelt(1500);
    let one = Math64x61.fromFelt(1);

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

    assert premia = 2020558154346487; // approx 0.0087 ETH

    // Test balance of lp tokens in the account after the option was bought
    let (bal_eth_lpt_1: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_call_addr,
        account=admin_addr
    );
    assert bal_eth_lpt_1.low = 5000000000000000000;

    let (bal_usd_lpt_1: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_put_addr,
        account=admin_addr
    );
    assert bal_usd_lpt_1.low = 5000000000;

    // Test unlocked capital in the pools after the option was bought
    let (call_pool_unlocked_capital_1) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    // size of the unlocked pool is 5ETH (original) - 1ETH (locked by the trade) + premium + 0.03*premium
    // 0.03 because of 3% fees calculated from premium
    assert call_pool_unlocked_capital_1 = 9225453211753752689;

    let (put_pool_unlocked_capital_1) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_unlocked_capital_1 = 11529215046068469760000;

    // Test balance of option tokens in the account after the option was bought
    let (bal_opt_long_call_tokens_1: Uint256) = ILPToken.balanceOf(
        contract_address=opt_long_call_addr,
        account=admin_addr
    );
    assert bal_opt_long_call_tokens_1.low = 1000000000000000000;

    ///////////////////////////////////////////////////
    // UPDATE THE ORACLE PRICE

    %{
        stop_mock_oracle_1()
        stop_mock_oracle_2 = mock_call(
            ids.EMPIRIC_ORACLE_ADDRESS, "get_value", [1450000000000000000000, 18, 0, 0]  # mock current ETH price at 1450
        )
    %}

    ///////////////////////////////////////////////////
    // WITHDRAW CAPITAL - WITHDRAW 40% of lp tokens
    let two_eth = Uint256(low = 2000000000000000000, high = 0);
    IAMM.withdraw_liquidity(
        contract_address=amm_addr,
        pooled_token_addr=myeth_addr,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        option_type=0,
        lp_token_amount=two_eth
    );

    // Test balance of lp tokens in the account after the option was bought and after withdraw
    let (bal_eth_lpt_2: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_call_addr,
        account=admin_addr
    );
    assert bal_eth_lpt_2.low = 3000000000000000000;

    let (bal_usd_lpt_2: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_put_addr,
        account=admin_addr
    );
    assert bal_usd_lpt_2.low = 5000000000;

    // Test unlocked capital in the pools after the option was bought and after withdraw
    let (call_pool_unlocked_capital_2) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    // 4617665128964013607 translates to 2.0025930258533364 (because 4617665128964013607 / 2**61)
    // before the withdraw there was 4.000902565738717 of unlocked capital
    // the withdraw meant that 40% of the value of pool was withdrawn
    //      which is 4.000902565738717 of unlocked capital plus remaining capital from short option
    //      where the remaining of short is (locked capital - premia of long option)... adjusted for fees
    //      the value of long was 0.005 (NOT CHECKED !!! -> JUST BY EYE)
    // So the value of pool was 4.000902565738717 + 1 - 0.005128716025264879 = 4.995773849713452
    // Withdrawed 40% -> 1.998309539885381 from unlocked capital
    // Remaining unlocked capital is 4.000902565738717 - 1.998309539885381 = 2.0025930258533364
    assert call_pool_unlocked_capital_2 = 4617665128964013607;

    let (put_pool_unlocked_capital_2) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_unlocked_capital_2 = 11529215046068469760000;

    // Test balance of option tokens in the account after the option was bought and after withdraw
    let (bal_opt_long_call_tokens_2: Uint256) = ILPToken.balanceOf(
        contract_address=opt_long_call_addr,
        account=admin_addr
    );
    assert bal_opt_long_call_tokens_2.low = 1000000000000000000;

    %{
        # optional, but included for completeness and extensibility
        stop_prank_amm()
        stop_mock_oracle_2()
        stop_warp_1()
    %}
    return ();
}


@external
func test_minimal_round_trip_put{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test
    // -> buy put option
    // -> withdraw half of the liquidity that was originally deposited from put pool
    alloc_locals;

    tempvar lpt_call_addr;
    tempvar lpt_put_addr;
    tempvar amm_addr;
    tempvar myusd_addr;
    tempvar myeth_addr;
    tempvar admin_addr;
    tempvar expiry;
    tempvar opt_long_put_addr;
    tempvar opt_short_put_addr;
    tempvar opt_long_call_addr;
    tempvar opt_short_call_addr;

    let strike_price = Math64x61.fromFelt(1500);

    %{
        ids.lpt_call_addr = context.lpt_call_addr
        ids.lpt_put_addr = context.lpt_put_addr
        ids.amm_addr = context.amm_addr
        ids.myusd_addr = context.myusd_address
        ids.myeth_addr = context.myeth_address
        ids.admin_addr = context.admin_address
        ids.expiry = context.expiry_0
        ids.opt_long_put_addr = context.opt_long_put_addr_0
        ids.opt_short_put_addr = context.opt_short_put_addr_0
        ids.opt_long_call_addr = context.opt_long_call_addr_0
        ids.opt_short_call_addr = context.opt_short_call_addr_0
    %}

    %{
        stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
        stop_mock_oracle_1 = mock_call(
            ids.EMPIRIC_ORACLE_ADDRESS, "get_value", [1400000000000000000000, 18, 0, 0]  # mock current ETH price at 1400
        )
    %}

    // Test initial balance of lp tokens in the account
    let (bal_eth_lpt_0: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_call_addr,
        account=admin_addr
    );
    assert bal_eth_lpt_0.low = 5000000000000000000;

    let (bal_usd_lpt_0: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_put_addr,
        account=admin_addr
    );
    assert bal_usd_lpt_0.low = 5000000000;

    // Test unlocked capital in the pools
    let (call_pool_unlocked_capital_0) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_unlocked_capital_0 = 11529215046068469760;

    let (put_pool_unlocked_capital_0) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_unlocked_capital_0 = 11529215046068469760000;

    // Test initial balance of option tokens in the account
    let (bal_opt_long_put_tokens_0: Uint256) = ILPToken.balanceOf(
        contract_address=opt_long_put_addr,
        account=admin_addr
    );
    assert bal_opt_long_put_tokens_0.low = 0;

    // Test pool_volatility -> 100
    let (call_volatility_0) = ILiquidityPool.get_pool_volatility(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr,
        maturity=expiry
    );
    assert call_volatility_0 = 230584300921369395200;
    let (put_volatility_0) = ILiquidityPool.get_pool_volatility(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr,
        maturity=expiry
    );
    assert put_volatility_0 = 230584300921369395200;

    // Test option position
    let (opt_long_put_position_0) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr,
        option_side=0,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_long_put_position_0 = 0;
    let (opt_short_put_position_0) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr,
        option_side=1,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_short_put_position_0 = 0;
    let (opt_long_call_position_0) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr,
        option_side=0,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_long_call_position_0 = 0;
    let (opt_short_call_position_0) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr,
        option_side=1,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_short_call_position_0 = 0;

    // Test lpool_balance
    let (call_pool_balance_0) = ILiquidityPool.get_lpool_balance(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_balance_0=11529215046068469760;
    let (put_pool_balance_0) = ILiquidityPool.get_lpool_balance(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_balance_0=11529215046068469760000;

    // Test pool_locked_capital
    let (call_pool_locked_capital_0) = ILiquidityPool.get_pool_locked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_locked_capital_0=0;
    let (put_pool_locked_capital_0) = ILiquidityPool.get_pool_locked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_locked_capital_0=0;

    ///////////////////////////////////////////////////
    // BUY THE PUT OPTION

    %{ stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) %}

    let strike_price = Math64x61.fromFelt(1500);
    let one = Math64x61.fromFelt(1);

    let (premia: Math64x61_) = IAMM.trade_open(
        contract_address=amm_addr,
        option_type=1,
        strike_price=strike_price,
        maturity=expiry,
        option_side=0,
        option_size=one,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr
    );

    assert premia = 234655350073966452800; // approx 101.7655361342164 USD...
    // notice difference in comparison to CALL premia... this is caused by different trade volatility
    // which is caused by different relative size of the option size (here 1ETH->1400USD against 5000USD pool)

    // Test balance of lp tokens in the account after the option was bought
    let (bal_eth_lpt_1: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_call_addr,
        account=admin_addr
    );
    assert bal_eth_lpt_1.low = 5000000000000000000;

    let (bal_usd_lpt_1: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_put_addr,
        account=admin_addr
    );
    assert bal_usd_lpt_1.low = 5000000000;

    // Test unlocked capital in the pools after the option was bought
    let (call_pool_unlocked_capital_1) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_unlocked_capital_1 = 11529215046068469760;

    let (put_pool_unlocked_capital_1) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    // size of the unlocked pool is 5kUSD (original) - 1ETH(=1500USD -> locked by the trade) + premium + 0.03*premium
    // 0.03 because of 3% fees calculated from premium
    assert put_pool_unlocked_capital_1 = 8312145542824114278327;

    // Test balance of option tokens in the account after the option was bought
    let (bal_opt_long_put_tokens_0: Uint256) = ILPToken.balanceOf(
        contract_address=opt_long_put_addr,
        account=admin_addr
    );
    assert bal_opt_long_put_tokens_0.low = 1000000000000000000;

    // Test pool_volatility -> 120 put and 100 call
    let (call_volatility_1) = ILiquidityPool.get_pool_volatility(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr,
        maturity=expiry
    );
    assert call_volatility_1 = 230584300921369395200;
    let (put_volatility_1) = ILiquidityPool.get_pool_volatility(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr,
        maturity=expiry
    );
    assert put_volatility_1 = 329406144173384850100;

    // Test option position
    let (opt_long_put_position_1) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr,
        option_side=0,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_long_put_position_1 = 0;
    let (opt_short_put_position_1) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr,
        option_side=1,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_short_put_position_1 = 2305843009213693952;
    let (opt_long_call_position_1) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr,
        option_side=0,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_long_call_position_1 = 0;
    let (opt_short_call_position_1) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr,
        option_side=1,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_short_call_position_1 = 0;

    // Test lpool_balance
    let (call_pool_balance_1) = ILiquidityPool.get_lpool_balance(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_balance_1=11529215046068469760;
    let (put_pool_balance_1) = ILiquidityPool.get_lpool_balance(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_balance_1=11770910056644655206327;

    // Test pool_locked_capital
    let (call_pool_locked_capital_1) = ILiquidityPool.get_pool_locked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_locked_capital_1=0;
    let (put_pool_locked_capital_1) = ILiquidityPool.get_pool_locked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_locked_capital_1=3458764513820540928000;

    ///////////////////////////////////////////////////
    // UPDATE THE ORACLE PRICE

    %{
        stop_mock_oracle_1()
        stop_mock_oracle_2 = mock_call(
            ids.EMPIRIC_ORACLE_ADDRESS, "get_value", [1450000000000000000000, 18, 0, 0]  # mock current ETH price at 1450
        )
    %}

    ///////////////////////////////////////////////////
    // WITHDRAW CAPITAL - WITHDRAW 40% of lp tokens
    let two_thousand_usd = Uint256(low = 2000000000, high = 0);
    IAMM.withdraw_liquidity(
        contract_address=amm_addr,
        pooled_token_addr=myusd_addr,
        quote_token_address=myusd_addr,
        base_token_address=myeth_addr,
        option_type=1,
        lp_token_amount=two_thousand_usd
    );

    // Test balance of lp tokens in the account after the option was bought and after withdraw
    let (bal_eth_lpt_2: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_call_addr,
        account=admin_addr
    );
    assert bal_eth_lpt_2.low = 5000000000000000000;

    let (bal_usd_lpt_2: Uint256) = ILPToken.balanceOf(
        contract_address=lpt_put_addr,
        account=admin_addr
    );
    assert bal_usd_lpt_2.low = 3000000000;

    // Test unlocked capital in the pools after the option was bought and after withdraw
    let (call_pool_unlocked_capital_2) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_unlocked_capital_2 = 11529215046068469760;

    // 3658935441669791923833 translates to 1586.8103019370387 (because 3658935441669791923833 / 2**61)
    // before the withdraw there was 3604.685906937039 of unlocked capital
    // the withdraw meant that 40% of the value of pool was withdrawn
    //      which is 3604.685906937039 of unlocked capital plus remaining capital from short option
    //      where the remaining of short is (locked capital - premia of long option)... adjusted for fees
    //      the value of long was 40.00310556296108 (NOT CHECKED !!! -> JUST BY EYE)
    // So the value of pool was 3604.685906937039 + 1400 - 40.00310556296108 = 5044.6890125
    // Withdrawed 40% -> 2017.875605 from unlocked capital
    // Remaining unlocked capital is 3604.685906937039 - 2017.875605 = 1586.810301937039
    let (put_pool_unlocked_capital_2) = IAMM.get_unlocked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_unlocked_capital_2 = 3659645983229807512265;

    // Test balance of option tokens in the account after the option was bought and after withdraw
    let (bal_opt_long_put_tokens_2: Uint256) = ILPToken.balanceOf(
        contract_address=opt_long_put_addr,
        account=admin_addr
    );
    assert bal_opt_long_put_tokens_2.low = 1000000000000000000;

    // Test pool_volatility -> 142.85714285714286 put and 100 call
    let (call_volatility_2) = ILiquidityPool.get_pool_volatility(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr,
        maturity=expiry
    );
    assert call_volatility_2 = 230584300921369395200;
    let (put_volatility_2) = ILiquidityPool.get_pool_volatility(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr,
        maturity=expiry
    );
    assert put_volatility_2 = 329406144173384850100;

    // Test option position
    let (opt_long_put_position_2) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr,
        option_side=0,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_long_put_position_2 = 0;
    let (opt_short_put_position_2) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr,
        option_side=1,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_short_put_position_2 = 2305843009213693952;
    let (opt_long_call_position_2) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr,
        option_side=0,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_long_call_position_2 = 0;
    let (opt_short_call_position_2) = ILiquidityPool.get_pools_option_position(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr,
        option_side=1,
        maturity=expiry,
        strike_price=strike_price
    );
    assert opt_short_call_position_2 = 0;

    // Test lpool_balance
    let (call_pool_balance_2) = ILiquidityPool.get_lpool_balance(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_balance_2=11529215046068469760;
    let (put_pool_balance_2) = ILiquidityPool.get_lpool_balance(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_balance_2=7118410497050348440265;

    // Test pool_locked_capital
    let (call_pool_locked_capital_2) = ILiquidityPool.get_pool_locked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_call_addr
    );
    assert call_pool_locked_capital_2=0;
    let (put_pool_locked_capital_2) = ILiquidityPool.get_pool_locked_capital(
        contract_address=amm_addr,
        lptoken_address=lpt_put_addr
    );
    assert put_pool_locked_capital_2=3458764513820540928000;

    %{
        # optional, but included for completeness and extensibility
        stop_prank_amm()
        stop_mock_oracle_2()
        stop_warp_1()
    %}
    return ();
}
