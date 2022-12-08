%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from openzeppelin.token.erc20.IERC20 import IERC20
from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool
from interface_option_token import IOptionToken
from interface_amm import IAMM


// Struct containing informations about the amm 
struct Stats {
    bal_lpt: felt,
    bal_opt: felt,
    pool_unlocked_capital: felt,
    pool_locked_capital: felt,
    lpool_balance: felt,
    pool_volatility: felt,
    opt_long_pos: felt,
    opt_short_pos: felt,
    pool_position_val: felt,
}

// Struct cointaing input data for get_stats function, 
struct StatsInput {
    user_addr: felt,
    lpt_addr: felt,
    amm_addr: felt,
    opt_addr: felt,
    expiry: felt,
    strike_price: felt,
}

func get_stats{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    input: StatsInput
) -> (
    stats: Stats
){
    alloc_locals;

    let (bal_lpt: Uint256) = ILPToken.balanceOf(
        contract_address=input.lpt_addr,
        account=input.user_addr
    );
    let (pool_unlocked_capital) = ILiquidityPool.get_unlocked_capital(
        contract_address=input.amm_addr,
        lptoken_address=input.lpt_addr
    );
    let (bal_opt_tokens: Uint256) = IOptionToken.balanceOf(
        contract_address=input.opt_addr,
        account=input.user_addr
    );
    let (pool_volatility) = ILiquidityPool.get_pool_volatility(
        contract_address=input.amm_addr,
        lptoken_address=input.lpt_addr,
        maturity=input.expiry
    );
    let (opt_long_pos) = ILiquidityPool.get_option_position(
        contract_address=input.amm_addr,
        lptoken_address=input.lpt_addr,
        option_side=0,
        maturity=input.expiry,
        strike_price=input.strike_price
    );
    let (opt_short_pos) = ILiquidityPool.get_option_position(
        contract_address=input.amm_addr,
        lptoken_address=input.lpt_addr,
        option_side=1,
        maturity=input.expiry,
        strike_price=input.strike_price
    );
    let (lpool_balance) = ILiquidityPool.get_lpool_balance(
        contract_address=input.amm_addr,
        lptoken_address=input.lpt_addr
    );
    let (pool_locked_capital) = ILiquidityPool.get_pool_locked_capital(
        contract_address=input.amm_addr,
        lptoken_address=input.lpt_addr
    );
    let (pools_pos_val) = ILiquidityPool.get_value_of_pool_position(
        contract_address = input.amm_addr,
        lptoken_address = input.lpt_addr
    );
    let bal_low = bal_lpt.low;
    let opt_bal_low = bal_opt_tokens.low;

    let stats = Stats(
        bal_lpt = bal_low,
        bal_opt = opt_bal_low,
        pool_unlocked_capital = pool_unlocked_capital.low,
        pool_locked_capital = pool_locked_capital.low,
        lpool_balance = lpool_balance.low,
        pool_volatility = pool_volatility,
        opt_long_pos = opt_long_pos,
        opt_short_pos = opt_short_pos,
        pool_position_val = pools_pos_val,
    );

    return(stats,);
}

func print_stats{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(stats: Stats) {
    alloc_locals;

    let lpt = stats.bal_lpt;
    let opt = stats.bal_opt;
    let puc = stats.pool_unlocked_capital;
    let plc = stats.pool_locked_capital;
    let lpb = stats.lpool_balance;
    let pv = stats.pool_volatility;
    let olp = stats.opt_long_pos;
    let osp = stats.opt_short_pos;
    let ppv = stats.pool_position_val;

    %{
        print("=================STATS=================")
        print(str(ids.lpt))
        print(str(ids.opt))
        print(str(ids.puc))
        print(str(ids.plc))
        print(str(ids.lpb))
        print(str(ids.pv))
        print(str(ids.olp))
        print(str(ids.osp))
        print(str(ids.ppv))
    %}
    

    return ();
}