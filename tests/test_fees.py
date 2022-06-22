"""contracts/fees.cairo test file."""
import math
import os

import pytest
from starkware.starknet.testing.starknet import Starknet

# The path to the contract source code.
CONTRACT_FILE = os.path.join("tests", "testable_fees.cairo")

Math64x61_FRACT_PART = 2 ** 61


@pytest.mark.asyncio
async def test_get_fees() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=CONTRACT_FILE,)

    result = await contract.testable_get_fees(100 * Math64x61_FRACT_PART).call()
    assert math.isclose(result.result[0] / Math64x61_FRACT_PART, 0.03 * 100, rel_tol=0.00001)
