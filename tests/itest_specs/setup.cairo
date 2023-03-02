%lang starknet

from interface_lptoken import ILPToken
from interface_amm import IAMM

from openzeppelin.token.erc20.IERC20 import IERC20
from math64x61 import Math64x61

from starkware.cairo.common.uint256 import Uint256, uint256_le



func deploy_setup{syscall_ptr: felt*, range_check_ptr}(){
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

    IAMM.add_lptoken(contract_address=amm_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=0, lptoken_address=lpt_call_addr);
    IAMM.add_lptoken(contract_address=amm_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=1, lptoken_address=lpt_put_addr);
    let five_eth_m64 = 11529215046068469760; //5 * 2 ** 61
    IAMM.set_pool_volatility_adjustment_speed(contract_address=amm_addr, lptoken_address=lpt_call_addr, new_speed=five_eth_m64);
    IAMM.set_pool_volatility_adjustment_speed(contract_address=amm_addr, lptoken_address=lpt_put_addr, new_speed=five_eth_m64);
    // Approve myUSD and myETH for use by amm

    let max_127bit_number = 0x80000000000000000000000000000000;
    let approve_amt = Uint256(low = max_127bit_number, high = max_127bit_number);
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
    IAMM.deposit_liquidity(contract_address=amm_addr, pooled_token_addr=myeth_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=0, amount=five_eth);
    let (bal_eth_lpt: Uint256) = ILPToken.balanceOf(contract_address=lpt_call_addr, account=admin_addr);
    assert bal_eth_lpt.low = 5000000000000000000;

    // Deposit 5_000 USD liquidity

    let five_thousand_usd = Uint256(low = 5000000000, high = 0);
    IAMM.deposit_liquidity(contract_address=amm_addr, pooled_token_addr=myusd_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=1, amount=five_thousand_usd);
    // FIXME lpt_call_addr should be lpt_put_addr
    let (bal_usd_lpt: Uint256) = ILPToken.balanceOf(contract_address=lpt_put_addr, account=admin_addr);
    assert bal_usd_lpt.low = 5000000000;

    let hundred_m64x61 = Math64x61.fromFelt(100);
    // Add long call option
    IAMM.add_option(
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
    IAMM.add_option(
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
    IAMM.add_option(
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
    IAMM.add_option(
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
