%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool
from types import PoolInfo, Pool

from starkware.cairo.common.cairo_builtins import HashBuiltin

namespace LPAggregateViewFunctions {
    func get_all_poolinfo{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;
        local amm_addr;
        %{
            ids.amm_addr = context.amm_addr
        %}
        let (poolinfo_len, poolinfo) = ILiquidityPool.get_all_poolinfo(
            contract_address=amm_addr,
        );
        
        //local poolitself: Pool* = new Pool(0, 0, 0);
        //let (correct_info: PoolInfo) = new PoolInfo(pool, lptoken_address, current_balance, free_capital, value_of_position);
        assert poolinfo[0].pool.option_type = 0;
        return ();
    }
}