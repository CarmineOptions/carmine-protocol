
import asyncio
import json
import time
import sys
import os 
import argparse
import logging
from typing import List

from starknet_py.contract import Contract
from starknet_py.net import AccountClient, KeyPair
from starknet_py.net.account.account import Account
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.client_models import TransactionStatus
from starknet_py.transaction_exceptions import TransactionRejectedError

MAX_FEE=int(1e16)
SUPPORTED_NETWORKS = ['testnet', 'mainnet']

def parse_envs() -> List[str]:
    PRIVATE_KEY = os.getenv('PRIVATE_KEY')
    PUBLIC_KEY = os.getenv('PUBLIC_KEY')

    if PRIVATE_KEY == None:
        raise ValueError("Missing PRIVATE_KEY ENV")

    if PUBLIC_KEY == None:
        raise ValueError("Missing PUBLIC_KEY ENV")

    return [PRIVATE_KEY,PUBLIC_KEY]

def setup_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
                        prog = 'Starknet Keeper bot',
                        description = 'Periodically calls predefined function on Starknet',
            )

    parser.add_argument(
        '--net', '-n', type = str
    )
    parser.add_argument(
        '--wallet_address', '-wa', type = str
    )
    parser.add_argument(
        '--contract_address', type = str
    )
    parser.add_argument(
        '--abi_path', type=str
    )
    parser.add_argument(
        '--function_name', '-f', type = str
    )
    parser.add_argument(
        '--function_arguments', '-fa', action='append', default = []
    )
    return parser

def get_abi(args: argparse.Namespace) -> List:
    with open(args.abi_path, 'r') as f:
        abi = json.load(f)

    return abi

def get_chain(args: argparse.Namespace) -> StarknetChainId:
    if args.net not in SUPPORTED_NETWORKS:
        raise ValueError(f'Unknown network, expected one of {SUPPORTED_NETWORKS}, got: {args.net}')

    return StarknetChainId.TESTNET if args.net == 'testnet' else StarknetChainId.MAINNET

async def main():

    logging.basicConfig(
        format='%(asctime)s - %(levelname)s - %(message)s', 
        datefmt='%d-%b-%y %H:%M:%S', 
        level=logging.INFO
    )

    parser = setup_parser()
    args = parser.parse_args()
    private_key, public_key = parse_envs()

    logging.info(f"Parsed args: {args}")

    abi = get_abi(args.abi_path)   
    chain = get_chain(args)

    logging.info(f"Selected chain: {chain}")

    client = GatewayClient(net=args.net)
    account = Account(
        client = client,
        address = args.wallet_address,
        key_pair = KeyPair(
            private_key = int(private_key, 16),
            public_key = int(public_key, 16)
        ),
        chain=chain,
    )
    
    contract = Contract(
        address = args.contract_address,
        abi = abi,
        provider = account,
    )
    
    # Invoke function
    call = contract.functions[args.function_name].prepare(
        *args.function_arguments,
    )

    logging.info(f"Executing call: {call}")

    response = await account.execute(calls=call, max_fee= MAX_FEE)

    logging.info(f"Sent transaction: {response}")

    await account.client.wait_for_tx(response.transaction_hash)

    try: 
        tx_status = await account.client.get_transaction_receipt(response.transaction_hash)

        if (tx_status.status == TransactionStatus.ACCEPTED_ON_L1 ) or (tx_status.status == TransactionStatus.ACCEPTED_ON_L2):
            logging.info(f"Tx receipt: {tx_status}")
        else:
            logging.error(f"Tx not accepted: {tx_status}")

    except TransactionRejectedError as err:
        logging.error(f"Transaction Rejected: {err}")

if __name__ == '__main__':
    asyncio.run(main())

# Example usage
#   PRIVATE_KEY=... \
#   PUBLIC_KEY=... \
#   python ./keeper.py \
#       --net testnet \
#       -wa $ACCOUNT_ADDR \
#       --contract_address $DUMMY_ADDR \
#       --abi_path ../build/dummy_abi.json \
#       --function_name write_value \
#       -fa 10 -fa 2


