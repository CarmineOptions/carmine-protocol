import asyncio
import json
from os import getenv
from typing import List, Any
from time import sleep

from starknet_py.contract import Contract
from starknet_py.net import KeyPair
from starknet_py.net.account.account import Account
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.contract import ContractFunction

# This script deploys the governance contract to the StarkNet network.

TESTNET = False
if not TESTNET:
    print("You are NOT deploying to testnet. Are you sure? (Ctrl+C to cancel)")
    sleep(5)
    print("Continuing...")

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
        compiled_contract=bytecode, max_fee=int(5e16)
    )
    print(f'Prepared declare transaction for {filename}'.format())
    resp = await account.client.declare(transaction=declare_transaction)
    print(f'Sent declare transaction {hex(resp.transaction_hash)}'.format())
    await account.client.wait_for_tx(resp.transaction_hash)
    declared_contract_class_hash = resp.class_hash
    return declared_contract_class_hash


async def deploy_new_proxy(proxy_class_hash: int, implementation_hash: int, proxy_abi_filename: str, call_initializer: bool = True, calldata: List[Any] = []) -> Contract:
    with open(proxy_abi_filename) as f:
        proxy_abi = json.load(f)

    if call_initializer:
        constructor_args = {"implementation_hash": implementation_hash, "selector": ContractFunction.get_selector("initializer"), "calldata": calldata}
    else:
        assert len(calldata) == 0
        constructor_args = {"implementation_hash": implementation_hash, "selector": 0, "calldata": []}

    deploy_result = await Contract.deploy_contract(
        account=account,
        class_hash=proxy_class_hash,
        abi=proxy_abi,
        constructor_args=constructor_args,
        max_fee=int(5e16),
    )
    print(f'Deploying an impl via new {proxy_abi_filename} in tx {hex(deploy_result.hash)}'.format())
    await deploy_result.wait_for_acceptance()
    print(f'Deployed an impl via new proxy at {hex(deploy_result.deployed_contract.address)}'.format())
    return deploy_result.deployed_contract


async def deploy_everything(
    governance_class_hash=None,
    governance_proxy_class_hash=None,
    governance_token_class_hash=None,
    generic_proxy_class_hash=None,
    amm_class_hash=None,
    lptoken_class_hash=None,
    option_token_class_hash=None,
):
    # declare all contracts

    if governance_class_hash is None:
        governance_class_hash = await declare_contract("build/governance.json")
        print(f'Declared governance contract {hex(governance_class_hash)}'.format())
    if governance_proxy_class_hash is None:
        governance_proxy_class_hash = await declare_contract("build/governance_proxy.json")
        print(f'Declared governance proxy contract {hex(governance_proxy_class_hash)}'.format())
    if generic_proxy_class_hash is None:
        generic_proxy_class_hash = await declare_contract("build/proxy.json")
        print(f'Declared generic proxy contract {hex(generic_proxy_class_hash)}'.format())
    if governance_token_class_hash is None:
        governance_token_class_hash = await declare_contract("build/governance_token.json")
        print(f'Declared governance token contract {hex(governance_token_class_hash)}'.format())
    if amm_class_hash is None:
        amm_class_hash = await declare_contract("build/amm.json")
        print(f'Declared AMM contract {hex(amm_class_hash)}'.format())
    if lptoken_class_hash is None:
        lptoken_class_hash = await declare_contract("build/lptoken.json")
        print(f'Declared LP token contract {hex(lptoken_class_hash)}'.format())
    if option_token_class_hash is None:
        option_token_class_hash = await declare_contract("build/option_token.json")
        print(f'Declared option token contract {hex(option_token_class_hash)}'.format())

    # deploy gov token

    governance_init_calldata = [generic_proxy_class_hash, governance_token_class_hash, amm_class_hash, lptoken_class_hash, option_token_class_hash]
    governance_contract = await deploy_new_proxy(governance_proxy_class_hash, governance_class_hash, "build/governance_proxy_abi.json", calldata=governance_init_calldata)
    print(f'Deployed governance at {hex(governance_contract.address)}'.format())


def main():
    if TESTNET:
        asyncio.run(deploy_everything(
        governance_class_hash=0xea323dfd569ed139b1eef9f18020810e944707fc3dc2fa41de3941b0724122,
        governance_proxy_class_hash=0x1336739e87e88374bfd22b51d3ada3b93ca0b8e329f184c062981afb0ee8f3a,
        generic_proxy_class_hash=0xeafb0413e759430def79539db681f8a4eb98cf4196fe457077d694c6aeeb82,
        governance_token_class_hash=0x134b48f0cdd4aeb76ee8e54b63227a1865d36719beee284b1bbc2b1ffc82884,
        amm_class_hash=0x69964b1e39b1c74de1f02967e0c063f0b2edf0d9d33eda6f917ea5ef21c03e9,
        lptoken_class_hash=0x26715c5e831414ddbd5d362582729d550e455876c3bef14342259d21e8d2404,
        option_token_class_hash=0x84f58cb1bae6c71e3fa654b5cf56ee3203ec8bc85f4360ed1dfef651a0ae4c,
        ))

    # MAINNET
    else:
        asyncio.run(deploy_everything(
            #governance_class_hash=
            generic_proxy_class_hash=0xeafb0413e759430def79539db681f8a4eb98cf4196fe457077d694c6aeeb82,
            #governance_token_class_hash=0x134b48f0cdd4aeb76ee8e54b63227a1865d36719beee284b1bbc2b1ffc82884,
            lptoken_class_hash=0x26715c5e831414ddbd5d362582729d550e455876c3bef14342259d21e8d2404,
        ))

if __name__ == "__main__":
    main()
