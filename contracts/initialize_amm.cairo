# Internal of the AMM

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
# from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_nn_le
# from starkware.cairo.common.math import assert_le, unsigned_div_rem
# from starkware.starknet.common.syscalls import storage_read, storage_write

from contracts.constants import (POOL_BALANCE_UPPER_BOUND, ACCOUNT_BALANCE_UPPER_BOUND, 
    TOKEN_A, TOKEN_B, OPTION_CALL, OPTION_PUT)
from contracts.amm import (pool_balance, account_balance, set_pool_balance, set_pool_volatility,
    set_account_balance)


# FIXME: this will have to be replaced by sending tokens from wallet to the pool(s).
# Adds fake tokens to the given account and for both pools (call and put pools).
@external
func add_fake_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt, amount_token_a : felt, amount_token_b : felt
):
    # 1) check that the final balance is below POOL_BALANCE_UPPER_BOUND with the additional amount
    let (pool_balance_call) = pool_balance.read(OPTION_CALL)
    let (pool_balance_put) = pool_balance.read(OPTION_PUT)

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
    # 1) set pool_balance
    set_pool_balance(option_type=OPTION_CALL, balance=12345)
    set_pool_balance(option_type=OPTION_PUT, balance=12345)
    
    # 2) Set pool_option_balance


    # 3) Set pool_volatility
    set_pool_volatility(OPTION_CALL, 1000, 100)
    set_pool_volatility(OPTION_PUT, 1000, 100)
    set_pool_volatility(OPTION_CALL, 1100, 100)
    set_pool_volatility(OPTION_PUT, 1100, 100)

    return ()
end