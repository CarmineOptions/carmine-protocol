import json
import subprocess
import os
import re
import time

options = []
main_contract_address = None
lptoken_contract_address = None


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


def add_option(inputs):
    contract = run_command(['starknet', 'deploy', '--contract', '/carmine/build/option_token.json', '--no_wallet', '--salt',
                            os.environ["SALT"], '--inputs', inputs[0], inputs[1], inputs[2], inputs[3], inputs[4], inputs[5], inputs[6], inputs[7], inputs[8], inputs[9], inputs[10], inputs[11], inputs[12]])

    print_status("deploy option", contract)

    add = run_command(['starknet', 'invoke', '--address', main_contract_address, '--abi', '/carmine/build/amm_abi.json', '--function', 'add_option',
                       '--inputs', inputs[12], inputs[11], inputs[10], inputs[7], inputs[8], inputs[9], lptoken_contract_address, contract[0], os.environ["INITIAL_VOLATILITY"]])
    print_status("add option", add)

    options.append(contract[0])
    return contract


def print_status(name, tx_list):
    status = get_status(tx_list[1])
    print(name, " has hash ", tx_list[0], " and status ", status)


def write_env_vars():
    f = open("/carmine/devnet/deployed_vars.env", "w")
    lines = []
    lines.append("export MAIN_CONTRACT_ADDRESS=" +
                 main_contract_address + "\n")
    lines.append("export LPTOKEN_CONTRACT_ADDRESS=" +
                 lptoken_contract_address + "\n")
    lines.append("export ETH_ADDRESS=" + os.environ["ETH_ADDRESS"] + "\n")
    lines.append("export USD_ADDRESS=" + os.environ["USD_ADDRESS"] + "\n")
    lines.append("export OPTION_TYPE=" + os.environ["OPTION_TYPE"] + "\n")
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
    lines.append("export OPTION_TYPE=" + os.environ["OPTION_TYPE"] + "\n")
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
    f.writelines(lines)


print('Starting')
temp = run_command(['starknet', 'deploy', '--contract', '/carmine/build/amm.json',
                    '--no_wallet', '--salt', os.environ['SALT']])
main_contract_address = temp[0]
print_status("DEPLOY MAIN CONTRACT", temp)

temp = run_command(["starknet", "deploy", "--contract", "/carmine/build/lptoken.json", "--no_wallet", "--salt", os.environ['SALT'], "--inputs",
                   "111", "11", "18", "0", "0", os.environ["ACCOUNT_0_ADDRESS"], main_contract_address])
lptoken_contract_address = temp[0]

print_status("DEPLOY LPTOKEN", temp)
print('lptoken contract address is:', lptoken_contract_address)
print('main contract address is:', main_contract_address)


temp = run_command(['starknet', 'invoke', '--address', main_contract_address, '--abi', '/carmine/build/amm_abi.json', '--function',
                    'add_lptoken', '--inputs', os.environ["USD_ADDRESS"], os.environ["ETH_ADDRESS"], os.environ["OPTION_TYPE"], lptoken_contract_address])
print_status("add_lptoken", temp)

temp = run_command(['starknet', 'invoke', '--address', os.environ["ETH_ADDRESS"], '--abi', '/carmine/build/lptoken_abi.json', '--function',
                   'approve', '--inputs', main_contract_address, "0x1bc16d674ec80000", "0"])
print_status("approve", temp)

temp = run_command(['starknet', 'invoke', '--address', main_contract_address, '--abi', '/carmine/build/amm_abi.json', '--function',
                   'deposit_liquidity', '--inputs', os.environ["ETH_ADDRESS"], os.environ["USD_ADDRESS"], os.environ["ETH_ADDRESS"], os.environ["OPTION_TYPE"], "0x1bc16d674ec80000", "0"])
print_status("deposit_liquidity", temp)

temp = add_option(['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                  os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE'], os.environ['STRIKE_PRICE'], os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])
print_status("first option", temp)


temp = add_option(['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                  os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE'], '3248180212899171532800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])
print_status("second option", temp)


temp = add_option(['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                  os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE'], '3228180212899171532800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])
print_status("third option", temp)


temp = add_option(['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                  os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE'], '3689348814741910323200', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])
print_status("fourth option", temp)


temp = add_option(['111', '11', '18', '0', '0', os.environ['ACCOUNT_0_ADDRESS'], main_contract_address, os.environ['USD_ADDRESS'],
                  os.environ['ETH_ADDRESS'], os.environ['OPTION_TYPE'], '3804640965202595020800', os.environ['MATURITY_1'], os.environ['OPTION_SIDE_LONG']])
print_status("fifth option", temp)

print('main contract address is:', main_contract_address)
print('lptoken contract address is:', lptoken_contract_address)

write_env_vars()

print('Done')
