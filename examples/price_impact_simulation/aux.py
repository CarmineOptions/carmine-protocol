import os
import json
from typing import Optional, Dict, List, Union

from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract

# Contracts path
AMM_CONTR_PATH = os.path.join('..', '..', 'contracts', 'amm.cairo')

# Other constants
USER_ID = 123
USER_ID_2 = 1
STARTING_TOKEN_BALANCE_1 = 20_000 * 2**61
STARTING_TOKEN_BALANCE_2 = 20_000 * 2**61

MATURITY = 1672527600  # 31/12/2022 -> matures in one year
STRIKE_PRICE = 2305843009213693952000  # 1000 * 2**61
CURRENT_PRICE = 1_200  # of ETH
CURRENT_PRICE_2 = 800  # of ETH


async def show_pool_volatility(amm: Starknet, return_res: bool = False) -> Optional[Dict[str, float]]:
    if not isinstance(amm, StarknetContract):
        raise TypeError('Not a Starknet Contract')

    new_pool_vol_0 = await amm.get_pool_volatility(option_type=0, maturity=MATURITY).call()
    new_pool_vol_1 = await amm.get_pool_volatility(option_type=1, maturity=MATURITY).call()

    if return_res:
        return {
            'pool_vol_CALL': new_pool_vol_0.result[0] / 2**61,
            'pool_vol_PUT': new_pool_vol_1.result[0] / 2**61
        }

    print("Call volatility: ", new_pool_vol_0.result[0] / 2**61)
    print("Put volatility: ", new_pool_vol_1.result[0] / 2**61)


async def show_current_premium(
    amm: StarknetContract, trade_size: int, return_res: bool = False
) -> Optional[Dict[str, float]]:
    if not isinstance(amm, StarknetContract):
        raise TypeError('Not a Starknet Contract')

    # Functions are only called, not invoked, so the state wont be changed but it'll return current premium
    prem_CALL = await amm.trade(
        account_id=USER_ID,
        option_type=0,
        strike_price=STRIKE_PRICE,
        maturity=MATURITY,
        side=0,
        option_size=trade_size
    ).call()

    prem_PUT = await amm.trade(
        account_id=USER_ID,
        option_type=1,
        strike_price=STRIKE_PRICE,
        maturity=MATURITY,
        side=0,
        option_size=trade_size
    ).call()

    if return_res:
        return {
            'prem_CALL': prem_CALL.result[0] / 2**61 * CURRENT_PRICE,
            'prem_PUT': prem_PUT.result[0] / 2**61,
        }

    print("Call Premium: ", prem_CALL.result[0] / 2**61 * CURRENT_PRICE)
    print("Put Premium: ", prem_PUT.result[0] / 2**61)


async def do_trade(amm: str, trade_size: int, option_type: int, side: int):
    if not isinstance(amm, StarknetContract):
        raise TypeError('Not a Starknet Contract')
    prem_0_0 = await amm.trade(
        account_id=USER_ID,
        option_type=option_type,
        strike_price=STRIKE_PRICE,
        maturity=MATURITY,
        side=side,
        option_size=trade_size
    ).invoke()
