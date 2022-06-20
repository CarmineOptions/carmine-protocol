"""contracts/amm.cairo test file."""
import os
import math

import pytest
from scipy.stats import norm
from starkware.starknet.testing.starknet import Starknet

# The path to the contract source code.
# TESTABLE_CONTRACT_FILE = os.path.join("tests", "testable_amm.cairo")
CONTRACT_FILE = os.path.join("contracts", "amm.cairo")
INITIALIZE_CONTRACT_FILE = os.path.join("contracts", "initialize_amm.cairo")

OPTION_CALL = 0
OPTION_PUT = 1

TRADE_SIDE_LONG = 0
TRADE_SIDE_SHORT = 1

Math64x61_FRACT_PART = 2 ** 61


@pytest.mark.asyncio
async def test_testable_do_trade() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=CONTRACT_FILE,)
    initialize_amm_contract = await starknet.deploy(source=INITIALIZE_CONTRACT_FILE,)

    await initialize_amm_contract.init_pool().invoke()
    account_id = 123456789
    await initialize_amm_contract.add_fake_tokens(
        account_id=account_id,
        amount_token_a=100 * Math64x61_FRACT_PART,
        amount_token_b=100 * Math64x61_FRACT_PART
    ).invoke()

    # FIXME: these numbers are hotfixes at the moment... at the moment they do not account for locked capital

    # Long call, 1000 strike, time_till_maturity=2305843009213693952 (=1 year)
    # current price = 1000 (set manually as hotfix as hard coded constant)
    result = await initialize_amm_contract.trade(
        account_id=account_id,
        option_type=OPTION_CALL,
        strike_price=1000*Math64x61_FRACT_PART,
        maturity=2305843009213693952,
        side=TRADE_SIDE_LONG,
        option_size=Math64x61_FRACT_PART,
    ).invoke()

    result = await initialize_amm_contract.get_pool_balance(OPTION_CALL).call()
    # Assuming the BS model is correctly computed
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 12445.12558804990, rel_tol=0.0001)

    # Short put, 1000 strike, time_till_maturity=2305843009213693952 (=1 year), size = 2
    # current price = 1000 (set manually as hotfix as hard coded constant)
    result = await initialize_amm_contract.trade(
        account_id=account_id,
        option_type=OPTION_PUT,
        strike_price=1000*Math64x61_FRACT_PART,
        maturity=2305843009213693952,
        side=TRADE_SIDE_SHORT,
        option_size=2*Math64x61_FRACT_PART,
    ).invoke()

    result = await initialize_amm_contract.get_pool_balance(OPTION_PUT).call()
    # Assuming the BS model is correctly computed
    # The PUT is in quote token (CALL in base token... base/quote = ETH/USDC),
    # thats why we have a difference here
    assert math.isclose(
        result.result[0] / Math64x61_FRACT_PART,
        12445 - 2 * 125.58804990779984,
        rel_tol=0.0001
    )


    print('---------------------------')
    print('put', result.result[0] / Math64x61_FRACT_PART)
    print('---------------------------')
    assert False
