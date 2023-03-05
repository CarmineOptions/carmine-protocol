%lang starknet

from tests.itest_specs.view_functions.liquidity_pool_basic import LPBasicViewFunctions
from interfaces.interface_lptoken import ILPToken
from interfaces.interface_option_token import IOptionToken
from interfaces.interface_amm import IAMM
from types import Math64x61_
from constants import EMPIRIC_ORACLE_ADDRESS

from openzeppelin.token.erc20.IERC20 import IERC20
from math64x61 import Math64x61

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256


namespace BLA {
    func bla{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        // test
        // -> sell call option
        // -> withdraw half of the liquidity that was originally deposited from call pool
        // -> close half of the bought option
        // -> settle pool
        // -> settle the option
        alloc_locals;

        tempvar lpt_call_addr;
        tempvar lpt_put_addr;
        tempvar amm_addr;
        tempvar myusd_addr;
        tempvar myeth_addr;
        tempvar admin_addr;
        tempvar expiry;
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
            ids.opt_long_call_addr = context.opt_long_call_addr_0
            ids.opt_short_call_addr = context.opt_short_call_addr_0
        %}

        tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
        %{
            stop_prank_amm = start_prank(context.admin_address, context.amm_addr)
            stop_mock_current_price = mock_call(
                ids.tmp_address, "get_spot_median", [1400000000000000000000, 18, 0, 0]  # mock current ETH price at 1400
            )
        %}


        ///////////////////////////////////////////////////
        // SELL THE CALL OPTION
        ///////////////////////////////////////////////////

        // testing burning short option if pool is short 

        %{ stop_warp_1 = warp(1000000000 + 60*60*12, target_contract_address=ids.amm_addr) %}

        let half = 5 * 10 ** 17;
        let one = 1 * 10 ** 18;
        let one_and_half = one + half;
        let two = 2 * 10 ** 18;

        let (_: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=0,
            option_size=two,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=10000000000000000000, // Disable check
            tx_deadline=99999999999, // Disable deadline
        );
        let (opt_short_call_position_0) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        let (opt_long_call_position_0) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        %{ print('opt_short_call_position_0: ', ids.opt_short_call_position_0) %}
        %{ print('opt_long_call_position_0: ', ids.opt_long_call_position_0) %}

        // to test burning the short... user need to have to have, but smaller to make sure the pool is overall short

        let (_: Math64x61_) = IAMM.trade_open(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=one,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=1, // Disable check
            tx_deadline=99999999999, // Disable deadline
        );
        let (opt_short_call_position_1) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        let (opt_long_call_position_1) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        %{ print('opt_short_call_position_1: ', ids.opt_short_call_position_1) %}
        %{ print('opt_long_call_position_1: ', ids.opt_long_call_position_1) %}

        // close the short
        let (_: Math64x61_) = IAMM.trade_close(
            contract_address=amm_addr,
            option_type=0,
            strike_price=strike_price,
            maturity=expiry,
            option_side=1,
            option_size=half,
            quote_token_address=myusd_addr,
            base_token_address=myeth_addr,
            limit_total_premia=10000000000000000000, // Disable check
            tx_deadline=99999999999, // Disable deadline
        );

        let (opt_long_call_position_0) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=0,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_long_call_position_0 = 0;

        let (opt_short_call_position_2) = IAMM.get_option_position(
            contract_address=amm_addr,
            lptoken_address=lpt_call_addr,
            option_side=1,
            maturity=expiry,
            strike_price=strike_price
        );
        assert opt_short_call_position_2 = one_and_half;
        return ();
    }
}
