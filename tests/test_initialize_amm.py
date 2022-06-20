"""contracts/option_pricing.cairo test file."""
import os
import math

import pytest
from starkware.starknet.testing.starknet import Starknet

# The path to the contract source code.
CONTRACT_FILE = os.path.join("contracts", "initialize_amm.cairo")

TOKEN_A = 1
TOKEN_B = 2

OPTION_CALL = 0
OPTION_PUT = 1

TRADE_SIDE_LONG = 0
TRADE_SIDE_SHORT = 1

Math64x61_FRACT_PART = 2 ** 61



@pytest.mark.asyncio
async def test_init_pool() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=CONTRACT_FILE,)

    # pool_balance
    result = await contract.get_pool_balance(OPTION_CALL).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)
    result = await contract.get_pool_balance(OPTION_PUT).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # account_balance
    account_id = 123456789
    result = await contract.get_account_balance(account_id, TOKEN_A).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)
    result = await contract.get_account_balance(account_id, TOKEN_B).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # pool_option_balance
    for option_type in [OPTION_CALL, OPTION_PUT]:
        for strike_price in [
            1000 * Math64x61_FRACT_PART,
            1100 * Math64x61_FRACT_PART,
            1200 * Math64x61_FRACT_PART
        ]:
            # maturity is 1.0 and 1.1... both * 2**61
            for maturity in [2305843009213693952, 2536427310135063347]:
                for side in [TRADE_SIDE_LONG, TRADE_SIDE_SHORT]:
                    result = await contract.get_pool_option_balance(
                        option_type,
                        strike_price * Math64x61_FRACT_PART,
                        maturity,
                        side
                    ).call()
                    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # pool_volatility
    for option_type in [OPTION_CALL, OPTION_PUT]:
        # maturity is 1.0 and 1.1... both * 2**61
        for maturity in [2305843009213693952, 2536427310135063347]:
            result = await contract.get_pool_volatility(option_type, maturity).call()
            assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # available_options
    for option_type in [OPTION_CALL, OPTION_PUT]:
        for strike_price in [
            1000 * Math64x61_FRACT_PART,
            1100 * Math64x61_FRACT_PART,
            1200 * Math64x61_FRACT_PART
        ]:
            # maturity is 1.0 and 1.1... both * 2**61
            for maturity in [2305843009213693952, 2536427310135063347]:
                result = await contract.get_available_options(
                    option_type,
                    strike_price,
                    maturity
                ).call()
                assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # ----------initialize pool----------
    await contract.init_pool().invoke()

    # pool_balance
    result = await contract.get_pool_balance(OPTION_CALL).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12345, abs_tol=0.0001)
    result = await contract.get_pool_balance(OPTION_PUT).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12345, abs_tol=0.0001)

    # account_balance
    account_id = 123456789
    result = await contract.get_account_balance(account_id, TOKEN_A).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)
    result = await contract.get_account_balance(account_id, TOKEN_B).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # pool_option_balance
    for option_type in [OPTION_CALL, OPTION_PUT]:
        for strike_price in [
            1000 * Math64x61_FRACT_PART,
            1100 * Math64x61_FRACT_PART,
            1200 * Math64x61_FRACT_PART
        ]:
            # maturity is 1.0 and 1.1... both * 2**61
            for maturity in [2305843009213693952, 2536427310135063347]:
                for side in [TRADE_SIDE_LONG, TRADE_SIDE_SHORT]:
                    result = await contract.get_pool_option_balance(
                        option_type,
                        strike_price * Math64x61_FRACT_PART,
                        maturity,
                        side
                    ).call()
                    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # pool_volatility
    for option_type in [OPTION_CALL, OPTION_PUT]:
        # maturity is 1.0 and 1.1... both * 2**61
        for maturity in [2305843009213693952, 2536427310135063347]:
            result = await contract.get_pool_volatility(option_type, maturity).call()
            assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 100, abs_tol=0.0001)

    # available_options
    # PUT and CALL were initialized with both maturities and with strikes 1000 and 1100
    for option_type in [OPTION_CALL, OPTION_PUT]:
        for strike_price in [1000 * Math64x61_FRACT_PART, 1100 * Math64x61_FRACT_PART]:
            # maturity is 1.0 and 1.1... both * 2**61
            for maturity in [2305843009213693952, 2536427310135063347]:
                result = await contract.get_available_options(
                    option_type,
                    strike_price,
                    maturity
                ).call()
                assert math.isclose(result.result[0], 1, abs_tol=0.0001)
    for option_type in [OPTION_CALL, OPTION_PUT]:
        strike_price = 1200 * Math64x61_FRACT_PART
        # maturity is 1.0 and 1.1... both * 2**61
        for maturity in [2305843009213693952, 2536427310135063347]:
            result = await contract.get_available_options(
                option_type,
                strike_price,
                maturity
            ).call()
            assert math.isclose(result.result[0], 0, abs_tol=0.0001)


@pytest.mark.asyncio
async def test_add_fake_tokens() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=CONTRACT_FILE,)

    # initialize pool
    await contract.init_pool().invoke()

    # pool_balance
    result = await contract.get_pool_balance(OPTION_CALL).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12345, abs_tol=0.0001)
    result = await contract.get_pool_balance(OPTION_PUT).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12345, abs_tol=0.0001)

    # account_balance
    account_id = 123456789
    result = await contract.get_account_balance(account_id, TOKEN_A).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)
    result = await contract.get_account_balance(account_id, TOKEN_B).call()
    assert math.isclose(result.result[0], 0, abs_tol=0.0001)


    # ----------------add fake tokens----------------
    account_id = 123456789
    await contract.add_fake_tokens(
        account_id=account_id,
        amount_token_a=100 * Math64x61_FRACT_PART,
        amount_token_b=90 * Math64x61_FRACT_PART
    ).invoke()
    account_id = 987654321
    await contract.add_fake_tokens(
        account_id=account_id,
        amount_token_a=50 * Math64x61_FRACT_PART,
        amount_token_b=40 * Math64x61_FRACT_PART
    ).invoke()

    # pool_balance
    result = await contract.get_pool_balance(OPTION_CALL).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12495, abs_tol=0.0001)
    result = await contract.get_pool_balance(OPTION_PUT).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12475, abs_tol=0.0001)

    # account_balance
    account_id = 123456789
    result = await contract.get_account_balance(account_id, TOKEN_A).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 100, abs_tol=0.0001)
    result = await contract.get_account_balance(account_id, TOKEN_B).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 90, abs_tol=0.0001)
    account_id = 987654321
    result = await contract.get_account_balance(account_id, TOKEN_A).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 50, abs_tol=0.0001)
    result = await contract.get_account_balance(account_id, TOKEN_B).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 40, abs_tol=0.0001)

    # pool_option_balance
    for option_type in [OPTION_CALL, OPTION_PUT]:
        for strike_price in [
            1000 * Math64x61_FRACT_PART,
            1100 * Math64x61_FRACT_PART,
            1200 * Math64x61_FRACT_PART
        ]:
            # maturity is 1.0 and 1.1... both * 2**61
            for maturity in [2305843009213693952, 2536427310135063347]:
                for side in [TRADE_SIDE_LONG, TRADE_SIDE_SHORT]:
                    result = await contract.get_pool_option_balance(
                        option_type,
                        strike_price * Math64x61_FRACT_PART,
                        maturity,
                        side
                    ).call()
                    assert math.isclose(result.result[0], 0, abs_tol=0.0001)

    # pool_volatility
    for option_type in [OPTION_CALL, OPTION_PUT]:
        # maturity is 1 and 1.1... it is written this way, because python rounds 1.1*230584300921369395200
        for maturity in [2305843009213693952, 2536427310135063347]:
            result = await contract.get_pool_volatility(option_type, maturity).call()
            assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 100, abs_tol=0.0001)
