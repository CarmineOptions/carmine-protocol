import asyncio
import json
from os import getenv
from time import sleep

from starknet_py.contract import Contract
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.net.account.account import Account
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.client_errors import ClientError



contract_address = (
    0x042a7d485171a01b8c38b6b37e0092f0f096e9d3f945c50c77799171916f5a54  # testnet production contract
    # 0x05cade694670f80dca1195c77766b643dce01f511eca2b7250ef113b57b994ec  # testnet "testdev" contract - staging
)
address = getenv("GOV_ADDRESS")
privkey = getenv("GOV_PRIVKEY")
pubkey = getenv("GOV_PUBKEY")
if address is None or privkey is None or pubkey is None:
    # user should load them from an .env file (or anyway else)
    raise Exception("Missing GOV_ADDRESS, GOV_PRIVKEY, or GOV_PUBKEY environment variables.")
testnet = "testnet"
# MATURITY_TO_BE_SETTLED = 1675987199
# MATURITY_TO_BE_SETTLED = 1674777599
MATURITY_TO_BE_SETTLED = 1677196799
MATURITY_TO_BE_SETTLED = 1678406399  # Thu Mar 09 2023 23:59:59 GMT+0000

# testdev
#MATURITY_TO_BE_SETTLED = 1675987199
# MATURITY_TO_BE_SETTLED = 1679615999
MATURITY_TO_BE_SETTLED = 1686873599

async def main():
    client = GatewayClient(net="mainnet")
    account = Account(
        client=client,
        address=address,
        key_pair=KeyPair(
            private_key=int(privkey, 16),
            public_key=int(pubkey, 16)
        ),
        chain=StarknetChainId.MAINNET,
    )

    with open("build/amm_abi.json") as f:
        abi = json.load(f)

    contract = Contract(
        address=contract_address,
        abi=abi,
        provider=account,
    )

    (lptokens,) = await contract.functions["get_all_lptoken_addresses"].call()

    calls = []

    for lptoken in lptokens:
        print('Getting options for LP token, ', lptoken)

        (all_options,) = await contract.functions["get_all_options"].call(lptoken)
        
        for i in range(int(len(all_options) / 6)):
            if all_options[i*6 + 1] == MATURITY_TO_BE_SETTLED:
                calls.append(
                    contract.functions["expire_option_token_for_pool"].prepare(
                        lptoken_address=lptoken,
                        option_side=int(all_options[i*6]),
                        strike_price=int(all_options[i*6 + 2]),
                        maturity=int(all_options[i*6 + 1]),
                    )
                )
                # Alternative way of settling - invoking one by one
                # await (
                #     await contract.functions["expire_option_token_for_pool"].invoke(
                #         lptoken_address=lptoken,
                #         option_side=int(all_options[i*6]),
                #         strike_price=int(all_options[i*6 + 2]),
                #         maturity=int(all_options[i*6 + 1]),
                #         max_fee=int(1e16)
                #     )
                # ).wait_for_acceptance()
                # print('----------------- ', i)


    # Executes only one transaction with prepared calls
    print('Starting to execute the multicall')

    try:
        transaction_response = await account.execute(calls=calls, max_fee=int(1e16))
    except ClientError as e:
        print(f'got {e}'.format())
        sleep(2)
    print(transaction_response)
    await account.client.wait_for_tx(transaction_response.transaction_hash)

    print(transaction_response)

    print('Multicall executed')

asyncio.run(main())
print('Everything is done')
