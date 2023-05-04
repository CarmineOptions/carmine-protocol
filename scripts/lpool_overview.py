import asyncio

from starknet_py.contract import Contract
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.hash.selector import get_selector_from_name
from starknet_py.net.client_models import Call

from datetime import datetime

TESTNET = False
AMM_ADDR = 0x076dbabc4293db346b0a56b29b6ea9fe18e93742c73f12348c8747ecfc1050aa # mainnet
client = GatewayClient(net="testnet") if TESTNET else GatewayClient(net="mainnet")

class Option:
    def __init__(self, option_side, maturity, strike_price, quote_token_address, base_token_address, option_type):
        self.option_side = option_side
        self.maturity = maturity
        self.strike_price = strike_price
        self.quote_token_address = quote_token_address
        self.base_token_address = base_token_address
        self.option_type = option_type
    
    def get_strike_price(self):
        return self.strike_price // 2**61

async def get_pool_unlocked_capital(lpt_addr, decimals: int, currency: str):
    get_unlocked_capital_call = Call(
        to_addr=AMM_ADDR,
        selector=get_selector_from_name('get_unlocked_capital'),
        calldata=[lpt_addr]
    )
    res = await client.call_contract(get_unlocked_capital_call)
    capital_human = res[0] / 10**decimals
    return f'Unlocked capital {capital_human} {currency}'.format()


async def get_pool_balance(lpt_addr, decimals: int, currency: str):
    get_balance_call = Call(
        to_addr=AMM_ADDR,
        selector=get_selector_from_name('get_lpool_balance'),
        calldata=[lpt_addr]
    )
    res = await client.call_contract(get_balance_call)
    capital_human = res[0] / 10**decimals
    return f'Total capital {capital_human} {currency}'.format()


async def get_pool_position_in_option(option, relevant_pool_addr):
    get_option_position_call = Call(
        to_addr=AMM_ADDR,
        selector=get_selector_from_name('get_option_position'),
        calldata=[relevant_pool_addr, option.option_side, option.maturity, option.strike_price],
    )
    res = await client.call_contract(get_option_position_call)
    formatted_date = datetime.utcfromtimestamp(option.maturity).strftime('%m%d')
    side = 'long' if option.option_side == 0 else 'short'
    type = 'call' if option.option_type == 0 else 'put'
    position_human = res[0] / 10**18
    return f'Pool option pos in {side} {type} {option.get_strike_price()} {formatted_date} is {position_human}'.format()
    


async def main():
    all_lptokens_call = Call(
        to_addr=AMM_ADDR,
        selector=get_selector_from_name('get_all_lptoken_addresses'),
        calldata=[],
    )
    res = await client.call_contract(all_lptokens_call)
    call_lptoken_addr = res[1]
    put_lptoken_addr = res[2]

    all_options_call = Call(
        to_addr=AMM_ADDR,
        selector=get_selector_from_name('get_all_options'),
        calldata=[call_lptoken_addr],
    )
    res = await client.call_contract(all_options_call)
    i = 1
    options_call = []
    while i < len(res):
        options_call.append(Option(res[i], res[i+1], res[i+2], res[i+3], res[i+4], res[i+5]))
        i += 6
    
    all_options_put_call = Call(
        to_addr=AMM_ADDR,
        selector=get_selector_from_name('get_all_options'),
        calldata=[put_lptoken_addr],
    )
    res = await client.call_contract(all_options_put_call)
    i = 1
    options_put = []
    while i < len(res):
        options_put.append(Option(res[i], res[i+1], res[i+2], res[i+3], res[i+4], res[i+5]))
        i += 6

    # pool unlocked capital
    # pool total capital
    coros = [
        get_pool_unlocked_capital(call_lptoken_addr, 18, 'ETH'),
        get_pool_unlocked_capital(put_lptoken_addr, 6, 'USDC'),
        get_pool_balance(call_lptoken_addr, 18, 'ETH'),
        get_pool_balance(put_lptoken_addr, 6, 'USDC')
    ]

    # pool position in options
    for option in options_call:
        coros.append(get_pool_position_in_option(option, call_lptoken_addr))
    for option in options_put:
        coros.append(get_pool_position_in_option(option, put_lptoken_addr))
    results = await asyncio.gather(*coros)
    for result in results:
        print(result)


if __name__ == "__main__":
    asyncio.run(main())
