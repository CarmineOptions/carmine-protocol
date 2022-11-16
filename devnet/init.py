import json
import subprocess
import os
import re
import time
from datetime import datetime, timedelta

options = []
main_contract_address = None
lptoken_contract_address = None
lptoken_contract_address_put = None
initial_liquidity = "0x8ac7230489e80000"


def wait_until(somepredicate, timeout, period=0.25, *args, **kwargs):
    mustend = time.time() + timeout
    while time.time() < mustend:
        if somepredicate(*args, **kwargs):
            return True
        time.sleep(period)
    return False


def get_status(hash):
    out = subprocess.run(['starknet', 'tx_status', '--hash',
                          hash], capture_output=True, text=True)
    result = json.loads(out.stdout)
    return result['tx_status']


def run_command(command):
    tx_regex = re.compile('\s(0x[a-z0-9]*)')
    output = subprocess.run(command, capture_output=True, text=True)
    if output.stderr:
        raise Exception(output.stderr)
    hashes = re.findall(tx_regex, output.stdout)
    return hashes


def add_option(type, inputs):
    pool = lptoken_contract_address if type == "call" else lptoken_contract_address_put
    contract = run_command(['starknet', 'deploy', '--contract', '/carmine/build/option_token.json', '--no_wallet', '--salt',
                            os.environ["SALT"], '--inputs', inputs[0], inputs[1], inputs[2], inputs[3], inputs[4], inputs[5], inputs[6], inputs[7], inputs[8], inputs[9], inputs[10], inputs[11], inputs[12]])

    run_command(['starknet', 'invoke', '--address', main_contract_address, '--abi', '/carmine/build/amm_abi.json', '--function', 'add_option',
                 '--inputs', inputs[12], inputs[11], inputs[10], inputs[7], inputs[8], inputs[9], pool, contract[0], os.environ["INITIAL_VOLATILITY"]])
    options.append(contract[0])
    return contract


def print_status(name, tx_list):
    status = get_status(tx_list[1])
    print(name, " has hash ", tx_list[0], " and status ", status)


def write_env_vars():
    f = open("/carmine/devnet/deployed_vars.env", "w")
    lines = []
    lines.append("# Generated on " +
                 datetime.today().strftime('%H-%M %d-%m-%Y') + "\n")
    lines.append("export MAIN_CONTRACT_ADDRESS=" +
                 main_contract_address + "\n")
    lines.append("export LPTOKEN_CONTRACT_ADDRESS=" +
                 lptoken_contract_address + "\n")
    lines.append("export LPTOKEN_CONTRACT_ADDRESS_PUT=" +
                 lptoken_contract_address_put + "\n")
    lines.append("export ETH_ADDRESS=" + os.environ["ETH_ADDRESS"] + "\n")
    lines.append("export USD_ADDRESS=" + os.environ["USD_ADDRESS"] + "\n")
    lines.append("export ACCOUNT_0_ADDRESS=" +
                 os.environ["ACCOUNT_0_ADDRESS"] + "\n")
    lines.append("export ACCOUNT_0_PUBLIC=" +
                 os.environ["ACCOUNT_0_PUBLIC"] + "\n")
    lines.append("export ACCOUNT_0_PRIVATE=" +
                 os.environ["ACCOUNT_0_PRIVATE"] + "\n")
    lines.append("export STARKNET_WALLET=" +
                 os.environ["STARKNET_WALLET"] + "\n")
    lines.append("export STRIKE_PRICE=" + os.environ["STRIKE_PRICE"] + "\n")
    lines.append("export MATURITY_1=" + os.environ["MATURITY_1"] + "\n")
    lines.append("export OPTION_TYPE_CALL=" +
                 os.environ["OPTION_TYPE_CALL"] + "\n")
    lines.append("export OPTION_TYPE_PUT=" +
                 os.environ["OPTION_TYPE_PUT"] + "\n")
    lines.append("export OPTION_SIDE_LONG=" +
                 os.environ["OPTION_SIDE_LONG"] + "\n")
    lines.append("export OPTION_SIDE_SHORT=" +
                 os.environ["OPTION_SIDE_SHORT"] + "\n")
    lines.append("export INITIAL_VOLATILITY=" +
                 os.environ["INITIAL_VOLATILITY"] + "\n")
    lines.append("export STARKNET_CHAIN_ID=" +
                 os.environ["STARKNET_CHAIN_ID"] + "\n")
    lines.append("export STARKNET_FEEDER_GATEWAY_URL=" +
                 os.environ["STARKNET_FEEDER_GATEWAY_URL"] + "\n")
    lines.append("export STARKNET_GATEWAY_URL=" +
                 os.environ["STARKNET_GATEWAY_URL"] + "\n")
    lines.append("export STARKNET_NETWORK_ID=" +
                 os.environ["STARKNET_NETWORK_ID"] + "\n")
    lines.append("export SALT=" + os.environ["SALT"] + "\n")
    for i, option in enumerate(options):
        lines.append("export OPTION_TOKEN_ADDRESS_" +
                     str(i) + "=" + option + "\n")

    f.writelines(lines)


start_time = time.time()
print('Starting', flush=True)
temp = run_command(['starknet', 'deploy', '--contract', '/carmine/build/amm.json',
                    '--no_wallet', '--salt', os.environ['SALT']])
main_contract_address = temp[0]

print("Deployed main contract", flush=True)

# USD_ADDRESS
# DEPLOY
# temp = run_command(['starknet', 'deploy', '--contract', '/carmine/build/lptoken.json', '--no_wallet', '--salt',
#                     os.environ['SALT'], '--inputs', '111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address])
# print("USD_ADDRESS:", temp[0])

# LPTOKEN_CONTRACT_ADDRESS <- CALL
# DEPLOY
temp = run_command(["starknet", "deploy", "--contract", "/carmine/build/lptoken.json", "--no_wallet", "--salt", os.environ['SALT'], "--inputs",
                    "111", "11", "18", "0", "0", os.environ["ACCOUNT_0_ADDRESS"], main_contract_address])
lptoken_contract_address = temp[0]

# ADD_LPTOKEN
temp = run_command(['starknet', 'invoke', '--address', main_contract_address, '--abi', '/carmine/build/amm_abi.json', '--function',
                    'add_lptoken', '--inputs', os.environ["USD_ADDRESS"], os.environ["ETH_ADDRESS"], os.environ["OPTION_TYPE_CALL"], lptoken_contract_address])

# APPROVE
temp = run_command(['starknet', 'invoke', '--address', os.environ["ETH_ADDRESS"], '--abi', '/carmine/build/lptoken_abi.json', '--function',
                    'approve', '--inputs', main_contract_address, initial_liquidity, "0"])

# DEPOSIT_LIQUIDITY
temp = run_command(['starknet', 'invoke', '--address', main_contract_address, '--abi', '/carmine/build/amm_abi.json', '--function',
                    'deposit_liquidity', '--inputs', os.environ["ETH_ADDRESS"], os.environ["USD_ADDRESS"], os.environ["ETH_ADDRESS"], os.environ["OPTION_TYPE_CALL"], initial_liquidity, "0"])

print("Deployed CALL liquidity pool", flush=True)

# LPTOKEN_CONTRACT_ADDRESS_PUT
# DEPLOY
temp = run_command(["starknet", "deploy", "--contract", "/carmine/build/lptoken.json", "--no_wallet", "--salt", "0x69", "--inputs",
                   "111", "11", "18", "0", "0", os.environ["ACCOUNT_0_ADDRESS"], main_contract_address])
lptoken_contract_address_put = temp[0]

# ADD_LPTOKEN
temp = run_command(['starknet', 'invoke', '--address', main_contract_address, '--abi', '/carmine/build/amm_abi.json', '--function',
                    'add_lptoken', '--inputs', os.environ["USD_ADDRESS"], os.environ["ETH_ADDRESS"], os.environ["OPTION_TYPE_PUT"], lptoken_contract_address_put])

# APPROVE
temp = run_command(['starknet', 'invoke', '--address', os.environ["ETH_ADDRESS"], '--abi', '/carmine/build/lptoken_abi.json', '--function',
                   'approve', '--inputs', main_contract_address, initial_liquidity, "0"])

# DEPOSIT_LIQUIDITY
temp = run_command(['starknet', 'invoke', '--address', main_contract_address, '--abi', '/carmine/build/amm_abi.json', '--function',
                   'deposit_liquidity', '--inputs', os.environ["USD_ADDRESS"], os.environ["USD_ADDRESS"], os.environ["ETH_ADDRESS"], os.environ["OPTION_TYPE_PUT"], initial_liquidity, "0"])

print("Deployed PUT liquidity pool", flush=True)

# LONG CALL options
temp = add_option("call", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                           os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_CALL'], os.environ['STRIKE_PRICE'], os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])

temp = add_option("call", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                           os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_CALL'], '3248180212899171532800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])

temp = add_option("call", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                           os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_CALL'], '3228180212899171532800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])

temp = add_option("call", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                           os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_CALL'], '3689348814741910323200', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])

temp = add_option("call", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                           os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_CALL'], '3804640965202595020800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])

print("Deployed LONG CALL options", flush=True)

# SHORT CALL options
temp = add_option("call", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                           os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_CALL'], os.environ['STRIKE_PRICE'], os.environ['MATURITY_1'], os.environ['OPTION_SIDE_SHORT']])

temp = add_option("call", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                           os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_CALL'], '3248180212899171532800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_SHORT']])

temp = add_option("call", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                           os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_CALL'], '3228180212899171532800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_SHORT']])

temp = add_option("call", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                           os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_CALL'], '3689348814741910323200', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_SHORT']])

temp = add_option("call", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                           os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_CALL'], '3804640965202595020800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_SHORT']])

print("Deployed SHORT CALL options", flush=True)

# LONG PUT options
temp = add_option("put", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                  os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_PUT'], '3228180212899171532800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])

temp = add_option("put", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                  os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_PUT'], '3689348814741910323200', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])

temp = add_option("put", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                  os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_PUT'], '3804640965202595020800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])

print("Deployed LONG PUT options", flush=True)

# SHORT PUT options
temp = add_option("put", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                  os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_PUT'], '3228180212899171532800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_SHORT']])

temp = add_option("put", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                  os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_PUT'], '3689348814741910323200', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_SHORT']])

temp = add_option("put", ['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                  os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE_PUT'], '3804640965202595020800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_SHORT']])

print("Deployed SHORT PUT options", flush=True)

write_env_vars()

print('Done')
print("Finished in %s seconds" %
      (timedelta(seconds=time.time() - start_time)), flush=True)
