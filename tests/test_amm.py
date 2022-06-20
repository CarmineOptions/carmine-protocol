"""contracts/amm.cairo test file."""
import os
import math

import pytest
from scipy.stats import norm
from starkware.starknet.testing.starknet import Starknet

# The path to the contract source code.
TESTABLE_CONTRACT_FILE = os.path.join("tests", "testable_amm.cairo")


Math64x61_FRACT_PART = 2 ** 61

@pytest.mark.asyncio
async def test_testable_do_trade() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=TESTABLE_CONTRACT_FILE,)

    result = await contract.testable_do_trade(
        account_id=1*Math64x61_FRACT_PART,
        option_type=0*Math64x61_FRACT_PART,
        strike_price=1900*Math64x61_FRACT_PART,
        maturity=int(0.1*Math64x61_FRACT_PART),
        side=0*Math64x61_FRACT_PART,
        option_size=1*Math64x61_FRACT_PART,
    ).call()
    print('---------------------------')
    print(result.result[0] / Math64x61_FRACT_PART)
    print('---------------------------')
    assert False
