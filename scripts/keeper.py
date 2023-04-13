
import requests
import asyncio
import json
import time
import sys
import os 
import argparse
import logging
from typing import List
from dataclasses import dataclass
import traceback

from starknet_py.contract import Contract
from starknet_py.net import AccountClient, KeyPair
from starknet_py.net.account.account import Account
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.client_models import TransactionStatus
from starknet_py.transaction_exceptions import TransactionRejectedError


MAX_FEE = int(1e16)
# MAX_FEE = int(1e3)
SUPPORTED_NETWORKS = ['testnet', 'mainnet']

@dataclass
class EnVars:
    private_key: str
    public_key: str
    tg_key: str
    tg_chat_id: str

def parse_envs() -> EnVars:
    PRIVATE_KEY = os.getenv('PRIVATE_KEY')
    PUBLIC_KEY = os.getenv('PUBLIC_KEY')
    TG_KEY = os.getenv("TG_KEY")
    TG_CHAT_ID = os.getenv("TG_CHAT_ID")

    if PRIVATE_KEY == None:
        raise ValueError("Missing PRIVATE_KEY ENV")

    if PUBLIC_KEY == None:
        raise ValueError("Missing PUBLIC_KEY ENV")

    if TG_KEY == None:
        raise ValueError("Missing TG_KEY ENV")

    if TG_CHAT_ID == None:
        raise ValueError("Missing TG_CHAT_ID ENV")

    return EnVars(
        private_key = PRIVATE_KEY,
        public_key = PUBLIC_KEY,
        tg_key = TG_KEY,
        tg_chat_id = TG_CHAT_ID
    )

def setup_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog='Starknet Keeper bot',
        description='Periodically calls predefined function on Starknet',
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
        '--function_arguments', default = [], type = json.loads
    )
    return parser

def get_abi(args: argparse.Namespace) -> List:
    with open(args.abi_path, 'r') as f:
        abi = json.load(f)

    return abi

def alert(msg: str, chat_id: str, api_key: str):
    # https://api.telegram.org/bot[BOT_API_KEY]/sendMessage?chat_id=[MY_CHANNEL_NAME]&text=[MY_MESSAGE_TEXT]

    params = {
        'chat_id': chat_id,
        'text': msg,
    }
    res = requests.get("https://api.telegram.org/bot" + api_key + "/sendMessage", params=params)
    res.raise_for_status()


def get_chain(args: argparse.Namespace) -> StarknetChainId:
    if args.net not in SUPPORTED_NETWORKS:
        raise ValueError(
            f'Unknown network, expected one of {SUPPORTED_NETWORKS}, got: {args.net}'
        )

    return StarknetChainId.TESTNET if args.net == 'testnet' else StarknetChainId.MAINNET

async def main():

    logging.basicConfig(
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%d-%b-%y %H:%M:%S',
        level=logging.INFO
    )
    enVars = parse_envs()
    try: 
        parser = setup_parser()
        args = parser.parse_args()

        logging.info(f"Parsed args: {args}")

        abi = get_abi(args)   
        chain = get_chain(args)

        logging.info(f"Selected chain: {chain}")

        client = GatewayClient(net=args.net)
        account = Account(
            client = client,
            address = args.wallet_address,
            key_pair = KeyPair(
                private_key = int(enVars.private_key, 16),
                public_key = int(enVars.public_key, 16)
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

        tracebacks = []

        for _ in range(3):
            response = await account.execute(calls = call, max_fee = MAX_FEE)
            logging.info(f"Sent transaction: {response}")
            try: 
                await account.client.wait_for_tx(response.transaction_hash)
                break
            except Exception as err:
                logging.error(f"Transaction Rejected: {err}")
                tracebacks.append("".join(traceback.format_exception(err, value=err, tb=err.__traceback__)))
                continue

        tx_status = await account.client.get_transaction_receipt(response.transaction_hash)

        if (tx_status.status == TransactionStatus.ACCEPTED_ON_L1) or (tx_status.status == TransactionStatus.ACCEPTED_ON_L2):
            logging.info(f"Tx SUCCESSFULL, receipt: {tx_status}")
        else:
            tracebacks.append(tx_status)
            logging.error(f"Tx NOT ACCEPTED: {tx_status}")

        
        if tracebacks:
            alert(f"Received {len(tracebacks)} errors:(( - \n {tracebacks}", enVars.tg_chat_id, enVars.tg_key)
        else: 
            alert(f"Update successfull: {tx_status} \n {call}", enVars.tg_chat_id, enVars.tg_key)

    except Exception as e:
        err_msg = "".join(traceback.format_exception(err, value=err, tb=err.__traceback__))
        alert(f"COMPLETE FAIL: {err_msg}", enVars.tg_chat_id, enVars.tg_key)

if __name__ == '__main__':
    asyncio.run(main())

# Example usage
#   PRIVATE_KEY=... \
#   PUBLIC_KEY=... \
#   TG_CHAT_ID=...\
#   TG_KEY=...\
#   python ./keeper.py \
#       --net testnet \
#       -wa $ACCOUNT_ADDR \
#       --contract_address $DUMMY_ADDR \
#       --abi_path ../build/dummy_abi.json \
#       --function_name write_value \
#       --function_arguments "[1, 2]"


