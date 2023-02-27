%lang starknet

from interface_lptoken import ILPToken
from interface_option_token import IOptionToken
from interface_amm import IAMM
from types import Math64x61_
from constants import EMPIRIC_ORACLE_ADDRESS

from tests.IERC20Mintable import IERC20
from math64x61 import Math64x61

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq

namespace LargeSizes {
    func execute_large_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        // buy open long call pos, close long call pos.
        alloc_locals;

        local lpt_call_addr;
        local lpt_put_addr;
        local amm_addr;
        local myusd_addr;
        local myeth_addr;
        local admin_addr;
        local expiry;
        local opt_long_call_addr;

        let strike_price = Math64x61.fromFelt(1500);
        %{
            ids.lpt_call_addr = context.lpt_call_addr
            ids.lpt_put_addr = context.lpt_put_addr
            ids.amm_addr = context.amm_addr
            ids.myusd_addr = context.myusd_address
            ids.myeth_addr = context.myeth_address
            ids.admin_addr = context.admin_address
            ids.expiry = context.expiry_0
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            stop_prank_myeth = start_prank(context.admin_address, context.myeth_address)
        %}
        local tmp_address = EMPIRIC_ORACLE_ADDRESS;
        let two_hundred_eth = Uint256(low = 1, high = 0);
        IERC20.mint(contract_address=myeth_addr, to=admin_addr, amount=two_hundred_eth);
        IERC20.mint(contract_address=myeth_addr, to=admin_addr, amount=two_hundred_eth);

        
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [140000000000, 8, 0, 0]  # mock current ETH price at 1400
            )
        %}

        %{ stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) %}
        
        IAMM.deposit_liquidity(contract_address=amm_addr, pooled_token_addr=myeth_addr, quote_token_address=myusd_addr, base_token_address=myeth_addr, option_type=0, amount=two_hundred_eth);


        let strike_price = Math64x61.fromFelt(1500);
        let big_option_size = 100 * 10**18;

        let (premia: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=big_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr
        );

        assert premia = 6446863776477606;

        let (premia_close: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=big_option_size,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr
        );

        assert premia_close = 5;
        return ();
    }
}
