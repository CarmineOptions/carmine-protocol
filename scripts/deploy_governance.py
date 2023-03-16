import asyncio
import json
import time

from starknet_py.abi import AbiParser
from starknet_py.contract import Contract
from starknet_py.net import AccountClient, KeyPair
from starknet_py.net.account.account import Account
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.contract import ContractFunction

# This script deploys the governance contract to the StarkNet network.

client = GatewayClient(net="testnet")
account = Account(
    client=client,
    address=int("...", 16),
    key_pair=KeyPair(
        private_key=int("...", 16),
        public_key=int("...", 16),
    ),
    chain=StarknetChainId.TESTNET,
)


async def declare_contract(filename: str):
    with open(filename) as file:
        bytecode = file.read()

    declare_transaction = await account.sign_declare_transaction(
        compiled_contract=bytecode, max_fee=int(1e16)
    )
    print("Prepared declare transaction")
    resp = await account.client.declare(transaction=declare_transaction)
    print(f'Sent declare transaction {transaction_hash}'.format())
    await account.client.wait_for_tx(resp.transaction_hash)
    declared_contract_class_hash = resp.class_hash
    return declared_contract_class_hash


async def deploy_new_proxy(proxy_class_hash: int, implementation_hash: int, proxy_filename: str):
    with open(proxy_filename) as f:
        gov_proxy_abi = json.load(f)

    constructor_args = {"implementation_hash": governance_class_hash, "selector": ContractFunction.get_selector("initializer"), "calldata": []}

    deploy_result = await Contract.deploy_contract(
        account=account,
        class_hash=governance_proxy_class_hash,
        abi=gov_proxy_abi,
        constructor_args=constructor_args,
        max_fee=int(1e16),
    )
    print(f'Deploying {proxy_filename} with implementation...'.format())
    await deploy_result.wait_for_acceptance()
    print(f'Deployed proxy with impl at {deploy_result.deployed_contract.address}'.format())
    contract = deploy_result.deployed_contract


async def deploy_everything(
    governance_class_hash=None,
    governance_proxy_class_hash=None,
    generic_proxy_class_hash=None,
):
    if governance_class_hash is None:
        governance_class_hash = await declare_contract("build/governance.json")
        print(f'Declared governance contract {hex(governance_class_hash)}'.format())
    if governance_proxy_class_hash is None:
        governance_proxy_class_hash = await declare_contract("build/governance_proxy.json")
        print(f'Declared governance proxy contract {hex(governance_proxy_class_hash)}'.format())
    if generic_proxy_class_hash is None:
        generic_proxy_class_hash = await declare_contract("build/proxy.json")
        print(f'Declared generic proxy contract {hex(generic_proxy_class_hash)}'.format())

    await deploy_new_proxy(governance_proxy_class_hash, governance_class_hash, "build/governance_proxy.json")


    # 0x01987cbd17808b9a23693d4de7e246a443cfe37e6e7fbaeabd7d7e6532b07c3d on t1 currently

def main():
    asyncio.run(deploy_everything(
        governance_class_hash=2089875954438886143157303418582248674925856379130087517923594115651773693014,
        governance_proxy_class_hash=543134489962147396177386602179459516776742454127805363778249628474714001210,
    ))

if __name__ == "__main__":
    main()
