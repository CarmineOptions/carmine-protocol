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
async def test_std_normal_cdf() -> None:
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
        result = await contract.std_normal_cdf(x=int(x * UNIT / 10)).call()
        # Maximal relative error on this test set is 0.0027662877116225743.
        assert math.isclose(expected, result.result[0] / result.result[1], rel_tol=0.0028)


# @pytest.mark.asyncio
# async def test_d1_d2() -> None:
#     # Create a new Starknet class that simulates the StarkNet
#     # system.
#     starknet = await Starknet.empty()
#
#     # Deploy the contract.
#     contract = await starknet.deploy(source=CONTRACT_FILE,)
#
#     contract.d1_d2(
#         sigma=0.01,
#         time_till_maturity_annualized=0.1,
#         strike_price=100,
#         underlying_price=100,
#         risk_free_rate_annualized=0.03
#     )


@pytest.mark.asyncio
async def test_black_scholes() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=CONTRACT_FILE,)

    contract.black_scholes(
        sigma=int(0.01 * UNIT),
        time_till_maturity_annualized=int(0.1 * UNIT),
        strike_price=int(100 * UNIT),
        underlying_price=int(100 * UNIT),
        risk_free_rate_annualized=int(0.03 * UNIT)
    )
