%lang starknet

from interfaces.interface_lptoken import ILPToken
from interfaces.interface_option_token import IOptionToken
from interfaces.interface_amm import IAMM
from types import Math64x61_
from constants import EMPIRIC_ORACLE_ADDRESS
from tests.itest_specs.setup import deploy_setup
from tests.itest_specs.basic_round_trip.long_put import LongPutRoundTrip
from tests.itest_specs.basic_round_trip.long_call import LongCallRoundTrip
from tests.itest_specs.basic_round_trip.short_put import ShortPutRoundTrip
from tests.itest_specs.basic_round_trip.short_call import ShortCallRoundTrip
from tests.itest_specs.expire_option_token_for_pool import ExpireOptionTokenForPool
// from tests.itest_specs.basic_round_trip.round_trip_for_non_eth_usd import NonEthRoundTrip
from tests.itest_specs.deposit_liquidity import DepositLiquidity
from tests.itest_specs.withdraw_liquidity import WithdrawLiquidity
from tests.itest_specs.trades.series_of_trades import SeriesOfTrades
from tests.itest_specs.addition_of_lp_tokens import AdditionOfLPTokens
from tests.itest_specs.addition_of_option_tokens import AdditionOfOptionTokens
from tests.itest_specs.view_functions.liquidity_pool_basic import LPBasicViewFunctions
from tests.itest_specs.view_functions.liquidity_pool_aggregate import LPAggregateViewFunctions

from openzeppelin.token.erc20.IERC20 import IERC20
from math64x61 import Math64x61

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_eq
from starkware.cairo.common.math import assert_le
from starkware.starknet.common.syscalls import get_block_timestamp


@external
func __setup__{syscall_ptr: felt*, range_check_ptr}(){
    // Makefile takes care of generation of build/ammcontract.cairo. Proxy is mocked.
    deploy_setup();
    return ();
}


@external
func test_lpt_attrs{syscall_ptr: felt*, range_check_ptr}() {
    AdditionOfLPTokens.lpt_attrs();
    return ();
}

@external
func test_addition_of_incorrect_lpt{syscall_ptr: felt*, range_check_ptr}() {
    AdditionOfLPTokens.add_incorrect_lpt();
    return ();
}

@external
func test_option_attrs{syscall_ptr: felt*, range_check_ptr}() {
    AdditionOfOptionTokens.option_attrs();
    return ();
}

@external
func test_addition_of_incorrect_option{syscall_ptr: felt*, range_check_ptr}() {
    AdditionOfOptionTokens.add_incorrect_option();
    return ();
}

@external
func test_trade_open{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    SeriesOfTrades.trade_open();
    return ();
}

@external
func test_trade_close{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    SeriesOfTrades.trade_close();
    return ();
}

// FIXME: Broken somewhere in expire_option_token, overflowing or sth
// @external
// func test_trade_settle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
//     SeriesOfTrades.trade_settle();
//     return ();
// }


@external
func test_withdraw_liquidity{syscall_ptr: felt*, range_check_ptr}() {
    // test withdraw half of the liquidity that was originally deposited (from both pools)
    WithdrawLiquidity.withdraw_liquidity();
    return ();
}

@external
func test_withdraw_liquidity_not_enough_unlocked{syscall_ptr: felt*, range_check_ptr}() {
    // test what happens when more capital is withdrawn than there is unlocked
    WithdrawLiquidity.withdraw_liquidity_not_enough_unlocked();
    return ();
}


@external
func test_withdraw_liquidity_not_enough_lptokens_call{syscall_ptr: felt*, range_check_ptr}() {
    // test what happens when more capital is withdrawn than there is unlocked
    WithdrawLiquidity.withdraw_liquidity_not_enough_lptokens_call();
    return ();
}

@external
func test_withdraw_liquidity_not_enough_lptokens_put{syscall_ptr: felt*, range_check_ptr}() {
    // test what happens when more capital is withdrawn than there is unlocked
    WithdrawLiquidity.withdraw_liquidity_not_enough_lptokens_put();
    return ();
}

// FIXME: This is also broken somewhere in the expire_option_token
// @external
// func test_non_eth_round_trip{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
//     // test
//     // buy call and put option
//     // withde
//     NonEthRoundTrip.min_round_trip_non_eth();
//     return ();
// }

@external
func test_deposit_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    DepositLiquidity.test_deposit();
    return ();
}

@external
func test_expire_option_token_for_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    ExpireOptionTokenForPool.test_expire_option_token_for_pool();
    return ();
}

@external
func test_minimal_round_trip_long_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test
    // -> buy call option
    // -> withdraw half of the liquidity that was originally deposited from call pool
    // -> close half of the bought option
    // -> settle pool
    // -> settle the option
    LongCallRoundTrip.minimal_round_trip_call();
    return ();
}


@external
func test_minimal_round_trip_short_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test
    // -> sell call option
    // -> withdraw half of the liquidity that was originally deposited from call pool
    // -> close half of the bought option
    // -> settle pool
    // -> settle the option
    ShortCallRoundTrip.minimal_round_trip_call();
    return ();
}


@external
func test_minimal_round_trip_long_put{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test
    // -> buy put option
    // -> withdraw half of the liquidity that was originally deposited from put pool
    // -> close half of the bought option
    // -> settle pool
    // -> settle the option
    LongPutRoundTrip.minimal_round_trip_put();
    return ();
}


@external
func test_minimal_round_trip_short_put{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test
    // -> sell put option
    // -> withdraw half of the liquidity that was originally deposited from put pool
    // -> close half of the bought option
    // -> settle pool
    // -> settle the option
    ShortPutRoundTrip.minimal_round_trip_put();
    return ();
}


@external
func test_get_all_lptoken_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    LPBasicViewFunctions.get_all_lptoken_addresses();
    return ();
}


@external
func test_get_available_lptoken_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    LPBasicViewFunctions.get_available_lptoken_addresses();
    return ();
}


@external
func test_get_all_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    LPBasicViewFunctions.get_all_options();
    return ();
}


@external
func test_get_all_non_expired_options_with_premia{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    LPBasicViewFunctions.get_all_non_expired_options_with_premia();
    return ();
}


@external
func test_get_option_with_position_of_user{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    LPBasicViewFunctions.get_option_with_position_of_user();
    return ();
}


@external
func test_get_all_poolinfo{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    LPAggregateViewFunctions.get_all_poolinfo();
    return ();
}


@external
func test_get_user_pool_infos{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    LPAggregateViewFunctions.get_user_pool_infos();
    return ();
}

@external
func test_get_total_premia{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    LPBasicViewFunctions.get_total_premia();
    return ();
}
