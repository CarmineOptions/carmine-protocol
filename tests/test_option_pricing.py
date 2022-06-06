"""contracts/option_pricing.cairo test file."""
import os
import math

import pytest
from scipy.stats import norm
from starkware.starknet.testing.starknet import Starknet

# The path to the contract source code.
CONTRACT_FILE = os.path.join("contracts", "option_pricing.cairo")
TESTABLE_CONTRACT_FILE = os.path.join("tests", "testable_option_pricing.cairo")


Math64x61_FRACT_PART = 2 ** 61

@pytest.mark.asyncio
async def test_std_normal_cdf() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=TESTABLE_CONTRACT_FILE,)

    # In an ideal world this would be done through pytest.mark.parametrize,
    # but that would be starting the Starknet.empty() over and over again.
    for x in range(-50, 50):
        expected = norm.cdf(x / 10)
        # Check the result of std_normal_cdf().
        result = await contract.testable_std_normal_cdf(x=int(x / 10 * Math64x61_FRACT_PART)).call()
        # Maximal relative error on this test set is 0.0027662877116225743.
        calculated = result.result[0] / Math64x61_FRACT_PART
        assert math.isclose(expected, calculated, rel_tol=0.00276)


@pytest.mark.asyncio
async def test_d1_d2() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=TESTABLE_CONTRACT_FILE,)

    # d_1 = 1/(sigma*sqrt(T-t) * (ln(S_t/K)+(r+sigma^2/2)(T-t))
    # d_2=d_1-\sigma\sqrt{T-t}

    def to_unit(x):
        return int(x * Math64x61_FRACT_PART)

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
            sigma=sigma,
            time_till_maturity_annualized=time_till_maturity_annualized,
            strike_price=strike_price,
            underlying_price=underlying_price,
            risk_free_rate_annualized=risk_free_rate_annualized,
        ).call()
        d_1, is_pos_d_1, d_2, is_pos_d_2 = res.result
        d_1_sign = 1 if is_pos_d_1 else -1
        d_2_sign = 1 if is_pos_d_2 else -1
        calculated_d_1 = d_1_sign * d_1 / Math64x61_FRACT_PART
        calculated_d_2 = d_2_sign * d_2 / Math64x61_FRACT_PART
        assert math.isclose(calculated_d_1, target_d_1, rel_tol=0.00001)
        assert math.isclose(calculated_d_2, target_d_2, rel_tol=0.00001)


@pytest.mark.asyncio
async def test_black_scholes() -> None:
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(source=CONTRACT_FILE,)

    # Manually calculated
    # d1, d2 = .95026443693, .94710215927],
        # C(S_t, t) = N(d_1)S_t - N(d_2)Ke^{-r(T-t)}
        # C(S_t, t) = N(.95026443693)*100 - N(.94710215927)*100*e^{-0.03*0.1}
        # C(S_t, t) = .8290110478497325*100 - .828206637720174*100*e^{-0.03*0.1}
        # C(S_t, t) = 82.90110478497325 - 82.8206637720174*e^{-0.003}
        # C(S_t, t) = 82.90110478497325 - 82.8206637720174*0.997004495503373
        # C(S_t, t) = 0.32853068369857397
        # P(S_t, t) = 99.7004495503373-100+0.32853068369857397
        # P(S_t, t) = 0.028980234035870467
    res = await contract.black_scholes(
        sigma=int(0.01 * Math64x61_FRACT_PART),
        time_till_maturity_annualized=int(0.1 * Math64x61_FRACT_PART),
        strike_price=int(100 * Math64x61_FRACT_PART),
        underlying_price=int(100 * Math64x61_FRACT_PART),
        risk_free_rate_annualized=int(0.03 * Math64x61_FRACT_PART)
    ).call()
    call_premia, put_premia = res.result
    calculated_call_premia = call_premia / Math64x61_FRACT_PART
    calculated_put_premia = put_premia / Math64x61_FRACT_PART

    assert math.isclose(calculated_call_premia, 0.3286343853078214, rel_tol=0.0004)
    assert math.isclose(calculated_put_premia, 0.02909146099561372, rel_tol=0.004)

    # this is market data
    #         put_sigma=0.92
    #         call_sigma=0.9
    #         time_till_maturity_annualized=8/365
    #         strike_price=1900
    #         underlying_price=1850
    #         risk_free_rate_annualized=0.03
    #     put premia = 80, call premia = 125
    # d_1 = 1/(sigma*sqrt{T-t}) * [ln(S_t/K)+(r+sigma^2/2)(T-t)]
    # d_1 = 1/(0.9*sqrt{8/365}) * [ln(1850/1900)+(0.03+0.9^2/2)(8/365)]
    # d_1 = 1/(0.9*0.14804664203952106) * [-0.026668247082161294+0.43500000000000005*0.021917808219178082]
    # d_1 = 1/(0.13324197783556896) * [-0.017134000506818826]
    # d_1 = -0.1285931114589392
    # d_2 = d_1-\sigma\sqrt{T-t}
    # d_2 = -0.1285931114589392 - 0.9 * 0.14804664203952106
    # d_2 = -0.26183508929450816
    # C(S_t, t) = N(d_1)S_t - N(d_2)Ke^{-r(T-t)}
    # C(S_t, t) = N(-0.1285931114589392)*1850 - N(-0.26183508929450816)*1900*e^{-0.03*8/365}
    # C(S_t, t) = 0.4488398086552598*1850 - 0.396724292591792*1900*e^{-0.03*8/365}
    # C(S_t, t) = 0.4488398086552598*1850 - 0.396724292591792*1900*e^{-0.0006575342465753425}
    # C(S_t, t) = 0.4488398086552598*1850 - 0.396724292591792*1900*0.9993426818816942
    # C(S_t, t) = 77.07347479842417
    # P(S_t, t) = K * e^{-r(T - t)} - S_t + C(S_t, t)
    # P(S_t, t) = 1900 * e^{-0.0006575342465753425} - 1850 + 77.07347479842417
    # P(S_t, t) = 1900 * 0.9993426818816942 - 1850 + 77.07347479842417
    # P(S_t, t) = 125.82457037364304

    res = await contract.black_scholes(
        sigma=int(0.9 * Math64x61_FRACT_PART),
        time_till_maturity_annualized=int(8/365 * Math64x61_FRACT_PART),
        strike_price=int(1900 * Math64x61_FRACT_PART),
        underlying_price=int(1850 * Math64x61_FRACT_PART),
        risk_free_rate_annualized=int(0.03 * Math64x61_FRACT_PART)
    ).call()
    call_premia, put_premia = res.result
    calculated_call_premia = call_premia / Math64x61_FRACT_PART
    calculated_put_premia = put_premia / Math64x61_FRACT_PART

    assert math.isclose(calculated_call_premia, 77.07347479842417, rel_tol=0.00016)
    assert math.isclose(calculated_put_premia, 125.82457037364304, rel_tol=0.0001)

    # Manually calculated
    # d1, d2 = -32.36765605597588, -32.370818333636045
        # C(S_t, t) = N(d_1)S_t - N(d_2)Ke^{-r(T-t)}
        # C(S_t, t) = N(-32.36765605597588)*90 - N(-32.370818333636045)*100*e^{-0.03*0.1}
        # C(S_t, t) = N(-32.36765605597588)*90 - N(-32.370818333636045)*100*0.997004495503373
        # C(S_t, t) = (3.915494716116091e-230)*90 - (3.534188324281756e-230)*100*0.997004495503373
        # C(S_t, t) = 3.435972400387069e-232
        # P(S_t, t) = 100*0.997004495503373-90+3.435972400387069e-232
        # P(S_t, t) = 9.700449550337297
    res = await contract.black_scholes(
        sigma=int(0.01 * Math64x61_FRACT_PART),
        time_till_maturity_annualized=int(0.1 * Math64x61_FRACT_PART),
        strike_price=int(100 * Math64x61_FRACT_PART),
        underlying_price=int(90 * Math64x61_FRACT_PART),
        risk_free_rate_annualized=int(0.03 * Math64x61_FRACT_PART)
    ).call()
    call_premia, put_premia = res.result
    calculated_call_premia = call_premia / Math64x61_FRACT_PART
    calculated_put_premia = put_premia / Math64x61_FRACT_PART

    assert math.isclose(calculated_call_premia, 3.435972400387069e-232,  abs_tol=0.0001)
    assert math.isclose(calculated_put_premia, 9.7004495503372972, rel_tol=0.0001)
