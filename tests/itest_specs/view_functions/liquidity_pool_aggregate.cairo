%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool
from types import PoolInfo, Pool

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from math64x61 import Math64x61



namespace LPAggregateViewFunctions {
    func get_all_poolinfo{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        local amm_addr;
        local myusd_addr;
        local myeth_addr;
        local lpt_call_addr;
        local lpt_put_addr;

        %{
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
        %}

        let (poolinfo_len, poolinfo) = ILiquidityPool.get_all_poolinfo(
            contract_address=amm_addr,
        );

        // There are onlly two pools
        assert poolinfo_len = 2;

        assert poolinfo[0].pool.option_type = 0;
        assert poolinfo[0].pool.quote_token_address = myusd_addr;
        assert poolinfo[0].pool.base_token_address = myeth_addr;
        assert poolinfo[0].lptoken_address = lpt_call_addr;
        assert poolinfo[0].staked_capital = Math64x61.fromFelt(5);
        assert poolinfo[0].unlocked_capital = Math64x61.fromFelt(5);
        assert poolinfo[0].value_of_pool_position = 0;

        assert poolinfo[1].pool.option_type = 1;
        assert poolinfo[1].pool.quote_token_address = myusd_addr;
        assert poolinfo[1].pool.base_token_address = myeth_addr;
        assert poolinfo[1].lptoken_address = lpt_put_addr;
        assert poolinfo[1].staked_capital = Math64x61.fromFelt(5000);
        assert poolinfo[1].unlocked_capital = Math64x61.fromFelt(5000);
        assert poolinfo[1].value_of_pool_position = 0;

        return ();
    }


    func get_user_pool_infos{syscall_ptr: felt*, range_check_ptr}() {
        alloc_locals;

        local amm_addr;
        local admin_address;
        local myusd_addr;
        local myeth_addr;
        local lpt_call_addr;
        local lpt_put_addr;

        %{
            ids.amm_addr = context.amm_addr
            ids.admin_address = context.admin_address
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
        %}

        let (user_pool_infos_len, user_pools_info) = ILiquidityPool.get_user_pool_infos(
            contract_address=amm_addr,
            user=admin_address
        );

        assert user_pool_infos_len = 2;

        assert user_pools_info[0].pool_info.pool.option_type = 0;
        assert user_pools_info[0].pool_info.pool.quote_token_address = myusd_addr;
        assert user_pools_info[0].pool_info.pool.base_token_address = myeth_addr;
        assert user_pools_info[0].pool_info.lptoken_address = lpt_call_addr;
        assert user_pools_info[0].pool_info.staked_capital = Math64x61.fromFelt(5);
        assert user_pools_info[0].pool_info.unlocked_capital = Math64x61.fromFelt(5);
        assert user_pools_info[0].pool_info.value_of_pool_position = 0;
        assert user_pools_info[0].value_of_user_stake.low = 5000000000000000000;
        assert user_pools_info[0].value_of_user_stake.high = 0;
        assert user_pools_info[0].size_of_users_tokens.low = 5000000000000000000;
        assert user_pools_info[0].size_of_users_tokens.high = 0;

        assert user_pools_info[1].pool_info.pool.option_type = 1;
        assert user_pools_info[1].pool_info.pool.quote_token_address = myusd_addr;
        assert user_pools_info[1].pool_info.pool.base_token_address = myeth_addr;
        assert user_pools_info[1].pool_info.lptoken_address = lpt_put_addr;
        assert user_pools_info[1].pool_info.staked_capital = Math64x61.fromFelt(5000);
        assert user_pools_info[1].pool_info.unlocked_capital = Math64x61.fromFelt(5000);
        assert user_pools_info[1].pool_info.value_of_pool_position = 0;
        assert user_pools_info[1].value_of_user_stake.low = 5000000000;
        assert user_pools_info[1].value_of_user_stake.high = 0;
        assert user_pools_info[1].size_of_users_tokens.low = 5000000000;
        assert user_pools_info[1].size_of_users_tokens.high = 0;

        return ();
    }
}