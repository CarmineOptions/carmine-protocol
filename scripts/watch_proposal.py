from starknet_py.net.gateway_client import GatewayClient
from starknet_py.hash.selector import get_selector_from_name
from starknet_py.net.client_models import Call
import asyncio

addr = 0x001405ab78ab6ec90fba09e6116f373cda53b0ba557789a4578d8c1ec374ba0f  
call_data = [14]
selector = 'get_vote_counts'
NET = GatewayClient(net="mainnet")

async def func_call():
    call = Call(
        to_addr=addr,
        selector=get_selector_from_name(selector),
        calldata=call_data
    )
    res = await NET.call_contract(call)
    print(f"Yay :) - {res[0] / 10**18:_.2f}")
    print(f"Nay :( - {res[1] / 10**18:_.2f}")

    return res[0]

async def main():
    res = await func_call()
    print(f"\033[91mVotes left\033[0m: {-(res / 10**18 - 2643292):_.2f}")
    print(f"\033[91mPerc left\033[0m: {(-(res / 10**18 - 2643292)) / 2643292:.2%}\n")


    subm_prop = 82282
    latest_block = await NET.get_block('latest')
    elapsed = latest_block.block_number - subm_prop

    print('Latest block: ', latest_block.block_number)
    print("Elapsed blocks: ", elapsed)
    print("\033[91mBlocks left\033[0m: ", 500 - elapsed)

if __name__ == "__main__":
    asyncio.run(main())