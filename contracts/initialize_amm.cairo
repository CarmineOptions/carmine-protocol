# Internal of the AMM

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn_le
from math64x61 import Math64x61

from contracts.amm import (pool_balance, account_balance, set_pool_balance, set_pool_volatility,
    set_account_balance, set_available_options)
from contracts.constants import (POOL_BALANCE_UPPER_BOUND, ACCOUNT_BALANCE_UPPER_BOUND, 
    TOKEN_A, TOKEN_B, OPTION_CALL, OPTION_PUT)


# FIXME: this will have to be replaced by sending tokens from wallet to the pool(s).
# Adds fake tokens to the given account and for both pools (call and put pools).
@external
func add_fake_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt, amount_token_a : felt, amount_token_b : felt
):
    alloc_locals
    # 1) check that the final balance is below POOL_BALANCE_UPPER_BOUND with the additional amount
    let (pbc) = pool_balance.read(OPTION_CALL)
    local pool_balance_call = pbc
    let (pbp) = pool_balance.read(OPTION_PUT)
    local pool_balance_put = pbp

    assert_nn_le(pool_balance_call, POOL_BALANCE_UPPER_BOUND - 1 - amount_token_a)
    assert_nn_le(pool_balance_put, POOL_BALANCE_UPPER_BOUND - 1 - TOKEN_B)

    # 2) check that the final balance is below POOL_BALANCE_UPPER_BOUND with the additional amount
    let (account_balance_call) = account_balance.read(account_id, TOKEN_A)
    let (account_balance_put) = account_balance.read(account_id, TOKEN_B)

    assert_nn_le(account_balance_call, ACCOUNT_BALANCE_UPPER_BOUND - 1 - amount_token_a)
    assert_nn_le(account_balance_put, ACCOUNT_BALANCE_UPPER_BOUND - 1 - amount_token_b)

    # 3) update pool_balance
    set_pool_balance(OPTION_CALL, pool_balance_call + amount_token_a)
    set_pool_balance(OPTION_PUT, pool_balance_put + amount_token_b)

    # 4) update account_balance
    set_account_balance(account_id, TOKEN_A, account_balance_call + amount_token_a)
    set_account_balance(account_id, TOKEN_B, account_balance_put + amount_token_b)

    return ()
end

# FIXME: this is here only until we are able to send in test tokens
@external
func init_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():

    alloc_locals

    # 1) set pool_balance
    let (balance) = Math64x61.fromFelt(12345)
    set_pool_balance(option_type=OPTION_CALL, balance=balance)
    set_pool_balance(option_type=OPTION_PUT, balance=balance)
    
    # 2) Set pool_option_balance
    # No need, at the start the option balance of the pools is zero


    # 3) Set pool_volatility
    # 1 = 100%
    let (volatility) = Math64x61.fromFelt(1)

    # in tests the current timestamp is set to 1672527600 - (365*60*60*24) = 1640991600
    # which is GMT: Friday 31. December 2021 23:00:00
    # the maturity is set to be in 0.1 years time and in 1 year
    let maturity_01 = 1644145200
    set_pool_volatility(OPTION_CALL, maturity_01, volatility)
    set_pool_volatility(OPTION_PUT, maturity_01, volatility)

    let maturity_1 = 1672527600
    set_pool_volatility(OPTION_CALL, maturity_1, volatility)
    set_pool_volatility(OPTION_PUT, maturity_1, volatility)

    # 4) Set option availability
    let (strike_1000) = Math64x61.fromFelt(1000)
    set_available_options(OPTION_CALL, strike_1000, maturity_01)
    set_available_options(OPTION_CALL, strike_1000, maturity_1)
    set_available_options(OPTION_PUT, strike_1000, maturity_01)
    set_available_options(OPTION_PUT, strike_1000, maturity_1)

    let (strike_1100) = Math64x61.fromFelt(1100)
    set_available_options(OPTION_CALL, strike_1100, maturity_01)
    set_available_options(OPTION_CALL, strike_1100, maturity_1)
    set_available_options(OPTION_PUT, strike_1100, maturity_01)
    set_available_options(OPTION_PUT, strike_1100, maturity_1)

    return ()
end