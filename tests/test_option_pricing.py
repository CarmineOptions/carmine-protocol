"""contracts/option_pricing.cairo test file."""
import os

import math
import pytest
from scipy.stats import norm
from starkware.starknet.testing.starknet import Starknet

# The path to the contract source code.
CONTRACT_FILE = os.path.join("contracts", "option_pricing.cairo")


UNIT = 10**16


@pytest.mark.asyncio
async def test_increase_balance() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=CONTRACT_FILE,)

    # In an ideal world this would be done through pytest.mark.parametrize,
    # but that would be starting the Starknet.empty() over and over again.
    for x in range(-50, 50):
        expected = norm.cdf(x / 10)
        # Check the result of std_normal_cdf().
        result = await contract.std_normal_cdf(x=int(x * (10**16) / 10)).call()
        # Maximal relative error on this test set is 0.0027662877116225743.
        assert math.isclose(expected, result.result[0] / result.result[1], rel_tol=0.0028)
