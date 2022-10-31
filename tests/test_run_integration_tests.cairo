%lang starknet

from interface_lptoken import ILPToken
from interface_liquidity_pool import ILiquidityPool
from interface_option_token import IOptionToken
from interface_amm import IAMM
from types import Math64x61_
from constants import EMPIRIC_ORACLE_ADDRESS
from build.ammcontract import fromUint256, toUint256
from tests.itest_specs.setup import deploy_setup
from tests.itest_specs.basic_round_trip.long_put import LongPutRoundTrip
from tests.itest_specs.basic_round_trip.long_call import LongCallRoundTrip
from tests.itest_specs.withdraw_liquidity import WithdrawLiquidity
from tests.itest_specs.trades.series_of_trades import SeriesOfTrades
from tests.itest_specs.addition_of_lp_tokens import AdditionOfLPTokens
from tests.itest_specs.addition_of_option_tokens import AdditionOfOptionTokens

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

    deploy_setup();

    return ();
}


@external
func test_lpt_attrs{syscall_ptr: felt*, range_check_ptr}() {
    // FIXME: missing tests for the state storage_vars in AMM (that the opt tokens were correctly
    // added)
    AdditionOfLPTokens.lpt_attrs();
    return ();
}


@external
func test_option_attrs{syscall_ptr: felt*, range_check_ptr}() {
    // FIXME: missing tests for the state storage_vars in AMM (that the lp tokens were correctly
    // added and pools correctly created)
    AdditionOfOptionTokens.option_attrs();
    return ();
}


@external
func test_trade_open{syscall_ptr: felt*, range_check_ptr}() {
    SeriesOfTrades.trade_open();
    return ();
}


@external
func test_withdraw_liquidity{syscall_ptr: felt*, range_check_ptr}() {
    // test withdraw half of the liquidity that was originally deposited (from both pools)
    WithdrawLiquidity.withdraw_liquidity();
    return ();
}


@external
func test_minimal_round_trip_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test
    // -> buy call option
    // -> withdraw half of the liquidity that was originally deposited from call pool
    // FIXME: TBD -> close half of the bought option
    // FIXME: TBD -> settle pool
    // FIXME: TBD -> settle the option
    LongCallRoundTrip.minimal_round_trip_call();
    return ();
}



@external
func test_minimal_round_trip_put{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test
    // -> buy put option
    // -> withdraw half of the liquidity that was originally deposited from put pool
    // -> close half of the bought option
    // -> settle pool
    // -> settle the option
    LongPutRoundTrip.minimal_round_trip_put();
    return ();
}
