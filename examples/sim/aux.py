import os
import json


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
CURRENT_PRICE_2 = 800


def pretty_dict(_dict, indent=4):
    if not isinstance(_dict, dict):
        raise TypeError('Not a dict')
    print(json.dumps(_dict, indent=indent))


async def show_account_balances(amm):
    if not isinstance(amm, StarknetContract):
        raise TypeError('Not a Starknet Contract')

    acc_bal_1 = await amm.get_account_balance(account_id=USER_ID, token_type=1).call()
    acc_bal_2 = await amm.get_account_balance(account_id=USER_ID, token_type=2).call()
    print("Balance A (ETH): ", acc_bal_1.result[0] / 2**61)
    print("Balance B: ", acc_bal_2.result[0] / 2**61)


async def show_pool_volatility(amm, return_res=False):
    if not isinstance(amm, StarknetContract):
        raise TypeError('Not a Starknet Contract')

    new_pool_vol_0 = await amm.get_pool_volatility(option_type=0, maturity=MATURITY).call()
    new_pool_vol_1 = await amm.get_pool_volatility(option_type=1, maturity=MATURITY).call()

    if return_res:
        return {
            'new_pool_vol_0': new_pool_vol_0.result[0] / 2**61,
            'new_pool_vol_1': new_pool_vol_1.result[0] / 2**61
        }

    print("Call volatility: ", new_pool_vol_0.result[0] / 2**61)
    print("Put volatility: ", new_pool_vol_1.result[0] / 2**61)


async def show_pool_balances(amm):
    if not isinstance(amm, StarknetContract):
        raise TypeError('Not a Starknet Contract')

    call_balance = await amm.get_pool_balance(option_type=0).call()
    put_balance = await amm.get_pool_balance(option_type=1).call()
    print("Call balance: ", call_balance.result[0] / 2**61)
    print("Put balance: ", put_balance.result[0] / 2**61)


async def show_pool_option_balances(amm):
    if not isinstance(amm, StarknetContract):
        raise TypeError('Not a Starknet Contract')

    bal_0_0 = await amm.get_pool_option_balance(option_type=0, strike_price=STRIKE_PRICE, maturity=MATURITY, side=0).call()
    bal_0_1 = await amm.get_pool_option_balance(option_type=0, strike_price=STRIKE_PRICE, maturity=MATURITY, side=1).call()
    bal_1_0 = await amm.get_pool_option_balance(option_type=1, strike_price=STRIKE_PRICE, maturity=MATURITY, side=0).call()
    bal_1_1 = await amm.get_pool_option_balance(option_type=1, strike_price=STRIKE_PRICE, maturity=MATURITY, side=1).call()

    print("Long call balance: ", bal_0_0.result[0]/2**61)
    print("Short call balance: ", bal_0_1.result[0]/2**61)
    print("Long put balance: ", bal_1_0.result[0]/2**61)
    print("Short put balance: ", bal_1_1.result[0]/2**61)


async def show_info(amm, name=''):
    if not isinstance(amm, StarknetContract):
        raise TypeError('Not a Starknet Contract')

    print('\033[1m' + "Amm: \033[0m" + name)
    print("Maturity: In 1 year")
    print("Strike price: ", STRIKE_PRICE / 2**61)
    print('\033[1m' + "Account balances: " + '\033[0m')
    await show_account_balances(amm)
    print('\033[1m' + "Pool balances: " + '\033[0m')
    await show_pool_balances(amm)
    print('\033[1m' + "Pool option balances" + '\033[0m')
    await show_pool_option_balances(amm)
    print('\033[1m' + "Pool volatility" + '\033[0m')
    await show_pool_volatility(amm)
    print('\033[1m' + "Premia for 1 ETH option(in USD)" + '\033[0m')
    await show_current_premium(amm, 1)
    print('\n')


async def show_current_premium(amm, trade_size, return_res=False):
    if not isinstance(amm, StarknetContract):
        raise TypeError('Not a Starknet Contract')

    # Functions are only called, not invoked, so the state wont be changes but it'll return current premium
    prem_CALL = await amm.trade(account_id=USER_ID, option_type=0, strike_price=STRIKE_PRICE, maturity=MATURITY, side=0, option_size=trade_size).call()
    prem_PUT = await amm.trade(account_id=USER_ID, option_type=1, strike_price=STRIKE_PRICE, maturity=MATURITY, side=1, option_size=trade_size).call()

    if return_res:
        return {
            'prem_CALL': prem_CALL.result[0] / 2**61 * CURRENT_PRICE,
            'prem_PUT': prem_PUT.result[0] / 2**61,
        }

    print("Call Premium: ", prem_0_0.result[0] / 2**61 * CURRENT_PRICE)
    print("Call Short Premium: ", prem_0_1.result[0] / 2**61 * CURRENT_PRICE)
    print("Put Long Premium: ", prem_1_0.result[0] / 2**61)
    print("Put Short Premium: ", prem_1_1.result[0] / 2**61)


async def do_trade(amm, trade_size, option_type, side):
    if not isinstance(amm, StarknetContract):
        raise TypeError('Not a Starknet Contract')
    prem_0_0 = await amm.trade(account_id=USER_ID, option_type=option_type, strike_price=STRIKE_PRICE, maturity=MATURITY, side=side, option_size=trade_size).invoke()
