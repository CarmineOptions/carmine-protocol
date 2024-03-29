import asyncio
import json
from os import getenv
import sys

from starknet_py.contract import Contract
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.net.account.account import Account
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.contract import ContractFunction

if len(sys.argv) != 2:
    raise Exception("Usage: python declare_contract.py PATH_TO_CONTRACT")
path_to_contract = sys.argv[1]

TESTNET = True

rpc_url = getenv('STARKNET_RPC')
if rpc_url is not None and TESTNET == False:
    print("using rpc")
    client = FullNodeClient(node_url=rpc_url)
else:
    client = GatewayClient(net="testnet") if TESTNET else GatewayClient(net="mainnet")
chain = StarknetChainId.TESTNET if TESTNET else StarknetChainId.MAINNET
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

async def declare_contract(filename: str):
    with open(filename) as file:
        bytecode = file.read()

    declare_transaction = await account.sign_declare_transaction(
        compiled_contract=bytecode, max_fee=int(1e16)
    )
    print(f'Prepared declare transaction for {filename}'.format())
    resp = await account.client.declare(transaction=declare_transaction)
    print(f'Sent declare transaction {hex(resp.transaction_hash)}'.format())
    await account.client.wait_for_tx(resp.transaction_hash)
    declared_contract_class_hash = resp.class_hash
    print(f'Declared contract {filename} with class hash {hex(declared_contract_class_hash)}'.format())
    return declared_contract_class_hash

if __name__ == "__main__":
    asyncio.run(declare_contract(path_to_contract))
