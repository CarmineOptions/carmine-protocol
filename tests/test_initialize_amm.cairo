%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn_le
from contracts.Math64x61 import Math64x61_fromFelt, Math64x61_div, Math64x61_FRACT_PART

from contracts.initialize_amm import add_fake_tokens, init_pool
from contracts.constants import (
    POOL_BALANCE_UPPER_BOUND,
    ACCOUNT_BALANCE_UPPER_BOUND,
    TOKEN_A,
    TOKEN_B,
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    TRADE_SIDE_SHORT,
)

@contract_interface
namespace ITestContract:
    func get_account_balance(account_id : felt, token_type : felt) -> (account_balance : felt):
    end

    func get_pool_balance(option_type : felt) -> (pool_balance : felt):
    end

    func get_pool_option_balance(
        option_type : felt, strike_price : felt, maturity : felt, side : felt
    ) -> (pool_option_balance : felt):
    end

    func get_pool_volatility(option_type : felt, maturity : felt) -> (pool_volatility : felt):
    end

    func get_available_options(option_type : felt, strike_price : felt, maturity : felt) -> (
        option_availability : felt
    ):
    end

    func init_pool():
    end

    func add_fake_tokens(accoutn_id : felt, amount_token_a : felt, amount_token_b : felt):
    end
end

@external
func __setup__():
    # Deploy contract
    %{ context.contract_a_address = deploy_contract("./contracts/initialize_amm.cairo").contract_address %}
    return ()
end

@external
func test_init_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    tempvar CONTRACT_ADDRESS
    %{ ids.CONTRACT_ADDRESS = context.contract_a_address %}

    # Test pool balances
    let (pool_balance_call) = ITestContract.get_pool_balance(CONTRACT_ADDRESS, OPTION_CALL)
    assert pool_balance_call = 0

    let (pool_balance_put) = ITestContract.get_pool_balance(CONTRACT_ADDRESS, OPTION_PUT)
    assert pool_balance_put = 0

    # Test account balances
    let account_id = 123456789

    let (account_balance_a) = ITestContract.get_account_balance(
        CONTRACT_ADDRESS, account_id, TOKEN_A
    )
    assert account_balance_a = 0

    let (account_balance_b) = ITestContract.get_account_balance(
        CONTRACT_ADDRESS, account_id, TOKEN_B
    )
    assert account_balance_b = 0

    # test several pool option balances
    const STRIKE_1000 = Math64x61_FRACT_PART * 1000
    const STRIKE_1100 = Math64x61_FRACT_PART * 1100
    const STRIKE_1200 = Math64x61_FRACT_PART * 1200

    const MATURITY_1 = 1644145200
    const MATURITY_2 = 1672527600

    let (option_pool_1) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1000, MATURITY_1, TRADE_SIDE_LONG
    )
    assert option_pool_1 = 0

    let (option_pool_2) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_PUT, STRIKE_1100, MATURITY_2, TRADE_SIDE_LONG
    )
    assert option_pool_2 = 0

    let (option_pool_3) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1200, MATURITY_2, TRADE_SIDE_LONG
    )
    assert option_pool_3 = 0

    let (option_pool_4) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_PUT, STRIKE_1200, MATURITY_1, TRADE_SIDE_SHORT
    )
    assert option_pool_4 = 0

    let (option_pool_5) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1000, MATURITY_2, TRADE_SIDE_SHORT
    )
    assert option_pool_5 = 0

    # test pool volatility
    let (pool_vol_1) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_CALL, MATURITY_1)
    assert pool_vol_1 = 0

    let (pool_vol_2) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_CALL, MATURITY_2)
    assert pool_vol_2 = 0

    let (pool_vol_3) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_PUT, MATURITY_1)
    assert pool_vol_3 = 0

    let (pool_vol_4) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_PUT, MATURITY_2)
    assert pool_vol_4 = 0

    # test available options

    let (available_option_1) = ITestContract.get_available_options(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1000, MATURITY_2
    )
    assert available_option_1 = 0

    let (available_option_2) = ITestContract.get_available_options(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1100, MATURITY_1
    )
    assert available_option_2 = 0

    let (available_option_3) = ITestContract.get_available_options(
        CONTRACT_ADDRESS, OPTION_PUT, STRIKE_1200, MATURITY_1
    )
    assert available_option_3 = 0

    let (available_option_4) = ITestContract.get_available_options(
        CONTRACT_ADDRESS, OPTION_PUT, STRIKE_1000, MATURITY_2
    )
    assert available_option_4 = 0

    # initialize pool
    ITestContract.init_pool(CONTRACT_ADDRESS)

    # check pool balances
    tempvar pool_balance = 12345 * Math64x61_FRACT_PART

    let (pool_balance_call) = ITestContract.get_pool_balance(CONTRACT_ADDRESS, OPTION_CALL)
    assert pool_balance_call = pool_balance

    let (pool_balance_put) = ITestContract.get_pool_balance(CONTRACT_ADDRESS, OPTION_PUT)
    assert pool_balance_put = pool_balance

    # check account balance
    let (account_balance_a) = ITestContract.get_account_balance(
        CONTRACT_ADDRESS, account_id, TOKEN_A
    )
    assert account_balance_a = 0

    let (account_balance_b) = ITestContract.get_account_balance(
        CONTRACT_ADDRESS, account_id, TOKEN_B
    )
    assert account_balance_b = 0

    # check pool option balances

    let (option_pool_1) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1000, MATURITY_1, TRADE_SIDE_LONG
    )
    assert option_pool_1 = 0

    let (option_pool_2) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_PUT, STRIKE_1100, MATURITY_2, TRADE_SIDE_LONG
    )
    assert option_pool_2 = 0

    let (option_pool_3) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1200, MATURITY_2, TRADE_SIDE_LONG
    )
    assert option_pool_3 = 0

    let (option_pool_4) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_PUT, STRIKE_1200, MATURITY_1, TRADE_SIDE_SHORT
    )
    assert option_pool_4 = 0

    let (option_pool_5) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1000, MATURITY_2, TRADE_SIDE_SHORT
    )
    assert option_pool_5 = 0

    # check pool volatility
    let pool_volatility = 1 * Math64x61_FRACT_PART

    let (pool_vol_1) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_CALL, MATURITY_1)
    assert pool_vol_1 = pool_volatility

    let (pool_vol_2) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_CALL, MATURITY_2)
    assert pool_vol_2 = pool_volatility

    let (pool_vol_3) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_PUT, MATURITY_1)
    assert pool_vol_3 = pool_volatility

    let (pool_vol_4) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_PUT, MATURITY_2)
    assert pool_vol_4 = pool_volatility

    # check available options
    let (available_option_1) = ITestContract.get_available_options(
        CONTRACT_ADDRESS, OPTION_PUT, STRIKE_1000, MATURITY_2
    )
    assert available_option_1 = 1

    let (available_option_2) = ITestContract.get_available_options(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1100, MATURITY_1
    )
    assert available_option_2 = 1

    # Strike 1200 should have no available options
    let (available_option_3) = ITestContract.get_available_options(
        CONTRACT_ADDRESS, OPTION_PUT, STRIKE_1200, MATURITY_1
    )
    assert available_option_3 = 0

    let (available_option_4) = ITestContract.get_available_options(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1200, MATURITY_2
    )
    assert available_option_4 = 0

    return ()
end

@external
func test_add_fake_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    tempvar CONTRACT_ADDRESS
    %{ ids.CONTRACT_ADDRESS = context.contract_a_address %}

    # Initialize pool (again)
    ITestContract.init_pool(CONTRACT_ADDRESS)

    # Test pool balance
    tempvar pool_balance = 12345 * Math64x61_FRACT_PART

    let (pool_balance_call) = ITestContract.get_pool_balance(CONTRACT_ADDRESS, OPTION_CALL)
    assert pool_balance_call = pool_balance

    let (pool_balance_put) = ITestContract.get_pool_balance(CONTRACT_ADDRESS, OPTION_PUT)
    assert pool_balance_put = pool_balance

    # Check account balance
    let account_id_1 = 123456789
    let account_id_2 = 987654321

    let (account_balance_a) = ITestContract.get_account_balance(
        CONTRACT_ADDRESS, account_id_1, TOKEN_A
    )
    assert account_balance_a = 0

    let (account_balance_b) = ITestContract.get_account_balance(
        CONTRACT_ADDRESS, account_id_1, TOKEN_B
    )
    assert account_balance_b = 0

    # Add fake tokens

    let amount_token_a_1 = 100 * Math64x61_FRACT_PART
    let amount_token_b_1 = 90 * Math64x61_FRACT_PART
    ITestContract.add_fake_tokens(
        CONTRACT_ADDRESS, account_id_1, amount_token_a_1, amount_token_b_1
    )

    let amount_token_a_2 = 50 * Math64x61_FRACT_PART
    let amount_token_b_2 = 40 * Math64x61_FRACT_PART
    ITestContract.add_fake_tokens(
        CONTRACT_ADDRESS, account_id_2, amount_token_a_2, amount_token_b_2
    )

    # Check pool balance
    tempvar pool_balance_1 = 12495 * Math64x61_FRACT_PART
    let (pool_balance_call) = ITestContract.get_pool_balance(CONTRACT_ADDRESS, OPTION_CALL)
    assert pool_balance_call = pool_balance_1

    tempvar pool_balance_2 = 12475 * Math64x61_FRACT_PART
    let (pool_balance_put) = ITestContract.get_pool_balance(CONTRACT_ADDRESS, OPTION_PUT)
    assert pool_balance_put = pool_balance_2

    # Check account balance
    let balance_a_1 = 100 * Math64x61_FRACT_PART
    let balance_b_1 = 90 * Math64x61_FRACT_PART

    let (account_balance_a_1) = ITestContract.get_account_balance(
        CONTRACT_ADDRESS, account_id_1, TOKEN_A
    )
    assert account_balance_a_1 = balance_a_1

    let (account_balance_b_1) = ITestContract.get_account_balance(
        CONTRACT_ADDRESS, account_id_1, TOKEN_B
    )
    assert account_balance_b_1 = balance_b_1

    let balance_a_2 = 50 * Math64x61_FRACT_PART
    let balance_b_2 = 40 * Math64x61_FRACT_PART

    let (account_balance_a_2) = ITestContract.get_account_balance(
        CONTRACT_ADDRESS, account_id_2, TOKEN_A
    )
    assert account_balance_a_2 = balance_a_2

    let (account_balance_b_2) = ITestContract.get_account_balance(
        CONTRACT_ADDRESS, account_id_2, TOKEN_B
    )
    assert account_balance_b_2 = balance_b_2

    # Check pool option balance
    const STRIKE_1000 = Math64x61_FRACT_PART * 1000
    const STRIKE_1100 = Math64x61_FRACT_PART * 1100
    const STRIKE_1200 = Math64x61_FRACT_PART * 1200

    const MATURITY_1 = 1644145200
    const MATURITY_2 = 1672527600

    let (option_pool_1) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1000, MATURITY_2, TRADE_SIDE_SHORT
    )
    assert option_pool_1 = 0

    let (option_pool_2) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_PUT, STRIKE_1100, MATURITY_1, TRADE_SIDE_LONG
    )
    assert option_pool_2 = 0

    let (option_pool_3) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1200, MATURITY_2, TRADE_SIDE_SHORT
    )
    assert option_pool_3 = 0

    let (option_pool_4) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_PUT, STRIKE_1200, MATURITY_2, TRADE_SIDE_LONG
    )
    assert option_pool_4 = 0

    let (option_pool_5) = ITestContract.get_pool_option_balance(
        CONTRACT_ADDRESS, OPTION_CALL, STRIKE_1000, MATURITY_1, TRADE_SIDE_SHORT
    )
    assert option_pool_5 = 0

    # Check pool volatility
    let pool_volatility = 1 * Math64x61_FRACT_PART

    let (pool_vol_1) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_CALL, MATURITY_1)
    assert pool_vol_1 = pool_volatility

    let (pool_vol_2) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_CALL, MATURITY_2)
    assert pool_vol_2 = pool_volatility

    let (pool_vol_3) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_PUT, MATURITY_1)
    assert pool_vol_3 = pool_volatility

    let (pool_vol_4) = ITestContract.get_pool_volatility(CONTRACT_ADDRESS, OPTION_PUT, MATURITY_2)
    assert pool_vol_4 = pool_volatility

    return ()
end
