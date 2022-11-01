#!/bin/bash

FILE_NAME="_current_vars.env"

# clear/create the vars file
echo "" >$FILE_NAME

store_var() {
  # add variable in the form
  # export KEY=VALUE
  echo "export $1=${!1}" >>$FILE_NAME
}

starknet_command() {
  echo $(starknet --chain_id $CHAIN_ID --network_id $NETWORK_ID --gateway_url $GATEWAY --feeder_gateway_url $GATEWAY $1)
}

echo "Initialising..."

MAIN_OUTPUT=$(starknet_command "deploy --contract /carmine/build/amm.json --no_wallet --salt $SALT")

echo "Deployed main contract..."

[[ $MAIN_OUTPUT =~ ([a-z0-9]{66}) ]] && export MAIN_CONTRACT_ADDRESS=${BASH_REMATCH[0]}

LPTOKEN_OUTPUT=$(starknet_command "deploy --contract ./build/lptoken.json --no_wallet --salt $SALT --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS --network alpha-goerli")

[[ $LPTOKEN_OUTPUT =~ ([a-z0-9]{66}) ]] && export LPTOKEN_CONTRACT_ADDRESS=${BASH_REMATCH[0]}

echo "Deployed lptoken..."

starknet_command "invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_lptoken --inputs $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $LPTOKEN_CONTRACT_ADDRESS"

starknet_command "invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0x1bc16d674ec80000 0"

starknet_command "invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function deposit_liquidity --inputs $ETH_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE 0x1bc16d674ec80000 0"

echo "Deposited liquidity..."

OPTION_1_OUT=$(starknet_command "deploy --contract ./build/option_token.json --no_wallet --salt $SALT --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $STRIKE_PRICE $MATURITY_1 $OPTION_SIDE_LONG")

echo "Deployed first option..."

[[ $OPTION_1_OUT =~ ([a-z0-9]{66}) ]] && export OPTION_TOKEN_ADDRESS_1=${BASH_REMATCH[0]}

starknet_command "invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs $OPTION_SIDE_LONG $MATURITY_1 $STRIKE_PRICE $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $LPTOKEN_CONTRACT_ADDRESS $OPTION_TOKEN_ADDRESS_1 $INITIAL_VOLATILITY"

TEST_BALANCE=$(starknet_command "call --address $OPTION_TOKEN_ADDRESS_1 --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS")

echo "Test option balance is $TEST_BALANCE"

echo "Storing ENV VARS"

store_var "MAIN_CONTRACT_ADDRESS"
store_var "LPTOKEN_CONTRACT_ADDRESS"
store_var "OPTION_TOKEN_ADDRESS_1"
store_var "ACCOUNT_0_ADDRESS"
store_var "ACCOUNT_0_PUBLIC"
store_var "ACCOUNT_0_PRIVATE"
store_var "ETH_ADDRESS"
store_var "USD_ADDRESS"
store_var "STRIKE_PRICE"
store_var "MATURITY_1"
store_var "OPTION_TYPE"
store_var "OPTION_SIDE_LONG"
store_var "OPTION_SIDE_SHORT"
store_var "INITIAL_VOLATILITY"
store_var "CHAIN_ID"
store_var "SALT"
store_var "NETWORK_ID"
# GATEWAY is different here and outside - gotta store it manually
echo "export GATEWAY=http://localhost" >>$FILE_NAME

echo "Done! Use ENV VARS from \"${FILE_NAME}\""

exec "$@"
