import asyncio
from os import getenv
from time import sleep

from starknet_py.contract import Contract
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.hash.selector import get_selector_from_name
from starknet_py.net.client_models import Call
from starknet_py.net.account.account import Account
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.client_errors import ClientError

from datetime import datetime

TESTNET = False
GOV_ADDR = 0x001405ab78ab6ec90fba09e6116f373cda53b0ba557789a4578d8c1ec374ba0f # mainnet
rpc_url = getenv('STARKNET_RPC')
chain = StarknetChainId.TESTNET if TESTNET else StarknetChainId.MAINNET
#client = FullNodeClient(node_url=rpc_url)
client = GatewayClient(net="testnet") if TESTNET else GatewayClient(net="mainnet")
address = getenv("GOV_ADDRESS")
privkey = getenv("GOV_PRIVKEY")
pubkey = getenv("GOV_PUBKEY")

if address is None or privkey is None or pubkey is None:
    # user should load them from an .env file (or anyway else)
    raise Exception("Missing GOV_ADDRESS, GOV_PRIVKEY, or GOV_PUBKEY environment variables.")

account = Account(
    client=client,
    address=int(address, 16),
    key_pair=KeyPair(
        private_key=int(privkey, 16),
        public_key=int(pubkey, 16),
    ),
    chain=chain,
)

async def apply_proposal(id):
    call = Call(to_addr=GOV_ADDR,
                selector=get_selector_from_name('add_2206_2906_options'),
                calldata=[])
    try:
        executed = await account.execute(calls=call,max_fee=100000000000000000)
        print(executed)
    except ClientError as e:
        if hasattr(e, 'message'):
            print(f'got {e.message}')
        else:
            print(f'Exception occurred: {e}')
        sleep(10)
        return await apply_proposal(id)

def main():
    asyncio.run(apply_proposal(15))

if __name__ == "__main__":
    main()
