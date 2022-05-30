"""contracts/option_pricing.cairo test file."""
import os
import math

from aiocache import cached
from aiocache.serializers import PickleSerializer
import pytest
from scipy.stats import norm
from starkware.starknet.testing.starknet import Starknet

# The path to the contract source code.
CONTRACT_FILE = os.path.join("contracts", "option_pricing.cairo")


UNIT = 10**8


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


@pytest.mark.asyncio
async def test_testable_d1_d2() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=CONTRACT_FILE,)

    # d_1 = 1/(sigma*sqrt(T-t) * (ln(S_t/K)+(r+sigma^2/2)(T-t))
    # d_2=d_1-\sigma\sqrt{T-t}

    def to_unit(x):
        return int(x * UNIT)

    inputs = [
        # [_sigma, _time_till_maturity_annualized, _strike_price, _underlying_price, _risk_free_rate_annualized],
        [to_unit(0.01), to_unit(0.1), to_unit(100), to_unit(100), to_unit(0.03), .95026443693, .94710215927],
        [to_unit(0.1), to_unit(0.1), to_unit(100), to_unit(100), to_unit(0.03), .11067971810589328, .07905694150420947],
        [to_unit(0.01), to_unit(0.5), to_unit(100), to_unit(100), to_unit(0.03), 2.124855877465575, 2.1177848096537097],
        [to_unit(0.01), to_unit(0.1), to_unit(90), to_unit(100), to_unit(0.03), 34.268184929737096, 34.26502265207693],
        [to_unit(0.01), to_unit(0.1), to_unit(100), to_unit(90), to_unit(0.03), -32.36765605597588, -32.370818333636045],
        [to_unit(0.01), to_unit(0.1), to_unit(100), to_unit(100), to_unit(0.1), 3.1638587989984632, 3.160696521338295],
    ]
    for (
            sigma,
            time_till_maturity_annualized,
            strike_price,
            underlying_price,
            risk_free_rate_annualized,
            target_d_1,
            target_d_2
    ) in inputs:
        res = await contract.testable_d1_d2(
            _sigma=sigma,
            _time_till_maturity_annualized=time_till_maturity_annualized,
            _strike_price=strike_price,
            _underlying_price=underlying_price,
            _risk_free_rate_annualized=risk_free_rate_annualized,
        ).call()
        d_1, is_pos_d_1, d_2, is_pos_d_2 = res.result
        d_1_sign = 1 if is_pos_d_1 else -1
        d_2_sign = 1 if is_pos_d_2 else -1
        calculated_d_1 = d_1_sign * d_1 / UNIT
        calculated_d_2 = d_2_sign * d_2 / UNIT
        assert math.isclose(calculated_d_1, target_d_1, rel_tol=0.00001)
        assert math.isclose(calculated_d_2, target_d_2, rel_tol=0.00001)


# 8 dni till maturity
# strike =
#         put_sigma=int(0.92 * UNIT),
#         call_sigma=int(0.9 * UNIT),
#         time_till_maturity_annualized=int(8/365* UNIT),
#         strike_price=int(1900 * UNIT),
#         underlying_price=int(1850 * UNIT),
#         risk_free_rate_annualized=int(0.03 * UNIT)
# put premia = 80, call premia = 125

@pytest.mark.asyncio
async def test_black_scholes() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=CONTRACT_FILE,)

    res = await contract.black_scholes(
        # sigma=int(0.9 * UNIT),
        # time_till_maturity_annualized=int(8/365 * UNIT),
        # strike_price=int(1900 * UNIT),
        # underlying_price=int(1850 * UNIT),
        # risk_free_rate_annualized=int(0.03 * UNIT)
        sigma=int(0.1 * UNIT),
        time_till_maturity_annualized=int(10 * UNIT),
        strike_price=int(1.1 * UNIT),
        underlying_price=int(1 * UNIT),
        risk_free_rate_annualized=int(0.03 * UNIT)
    ).call()
    call_premia, put_premia, base = res.result
    print(call_premia, put_premia, base)
    print(call_premia / base, put_premia / base)
    assert False

