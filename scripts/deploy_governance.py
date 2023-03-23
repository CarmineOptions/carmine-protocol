import asyncio
import json
import time
from os import getenv
from typing import List, Any

from starknet_py.abi import AbiParser
from starknet_py.contract import Contract
from starknet_py.net import AccountClient, KeyPair
from starknet_py.net.account.account import Account
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.contract import ContractFunction

# This script deploys the governance contract to the StarkNet network.
# TODO multicalls, maybe, though it can save us 10 dollars at most?

client = GatewayClient(net="testnet")
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
    chain=StarknetChainId.TESTNET,
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
        max_fee=int(1e16),
    )
    print(f'Deploying an impl via new {proxy_abi_filename} in tx {hex(deploy_result.hash)}'.format())
    await deploy_result.wait_for_acceptance()
    print(f'Deployed an impl via new proxy at {hex(deploy_result.deployed_contract.address)}'.format())
    return deploy_result.deployed_contract

# TODO upgrade_via_proxy, should also fetch ABI from future impl class hash to ensure we won't kill the proxy

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

    gov_token_contract = await deploy_new_proxy(generic_proxy_class_hash, governance_token_class_hash, "build/proxy_abi.json", call_initializer=False)
    print(f'Deployed governance token at {hex(gov_token_contract.address)}'.format())
    # governance contract initializer initalizes the governance token (calls its initializer...). This could be called in a multicall to prevent "frontrunning", though there is no MEV in this case.
    gov_token_contract_address = gov_token_contract.address

    # deploy AMM
    amm_contract = await deploy_new_proxy(generic_proxy_class_hash, amm_class_hash, "build/amm_abi.json", call_initializer=False)
    print(f'Deployed AMM at {hex(amm_contract.address)}'.format())
    amm_contract_address = amm_contract.address

    governance_init_calldata = [gov_token_contract_address, amm_contract_address]
    governance_contract = await deploy_new_proxy(governance_proxy_class_hash, governance_class_hash, "build/governance_proxy_abi.json", calldata=governance_init_calldata)
    print(f'Deployed governance at {hex(governance_contract.address)}'.format())


def main():
    asyncio.run(deploy_everything(
       #governance_class_hash=0x73aa0bd03bbe7d40981283592014f0179cd0a19f26aa46be62dc09db70639ab,
       governance_proxy_class_hash=0x3c28875512f9abeb60bab6c928dd725f074063987082cb6d7d6a7ed4d203601,
       generic_proxy_class_hash=0xeafb0413e759430def79539db681f8a4eb98cf4196fe457077d694c6aeeb82,
       governance_token_class_hash=0x1b555006a1646575886d7eb73b6939a5105c668bdbc4e9ed33ab120ca6b60b2,
       amm_class_hash=0x2571df9988d465812bb456930491f4b9d01c1f568b0a0fa7625c41d59d1b6ab,
       lptoken_class_hash='DONOTDECLARE',
       option_token_class_hash='DONOTDECLARE',
    ))

if __name__ == "__main__":
    main()
