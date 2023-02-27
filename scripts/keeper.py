
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

MAX_FEE=int(1e16)

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
        '--contract_address', type = str
    )
    parser.add_argument(
        '--net', '-n', type = str
    )
    parser.add_argument(
        '--function_name', '-f', type = str
    )
    return parser


def main():

    logging.basicConfig(
        format='%(asctime)s - %(levelname)s - %(message)s', 
        datefmt='%d-%b-%y %H:%M:%S', 
        level=logging.INFO
    )

    parser = setup_parser()
    args = parser.parse_args()
    logging.info(f"Parsed args: {args}")

    acc_addres, acc_key = parse_envs()


if __name__ == '__main__':
    main()






