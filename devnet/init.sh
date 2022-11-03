#!/bin/bash

FILE_NAME="_current_vars.env"

OPTION_COUNTER=1

# add_option (name symbol decimals initial_supply1 initial_supply2 recipient owner quote_token_address base_token_address option_type strike_price maturity side)
add_option() {
  TMP=$(starknet deploy --contract ./build/option_token.json --no_wallet --salt $SALT --inputs $1 $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13})

  [[ $TMP =~ ([a-z0-9]{66}) ]]

  TX=${BASH_REMATCH[0]}
  export OPTION_TOKEN_ADDRESS_${OPTION_COUNTER}=$TX

  starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs ${13} ${12} ${11} $8 $9 ${10} $LPTOKEN_CONTRACT_ADDRESS $TX $INITIAL_VOLATILITY

  echo "Stored OPTION_TOKEN_ADDRESS_${OPTION_COUNTER} with value ${TX}"
  ((OPTION_COUNTER++))
}

store_var() {
  # add variable in the form
  # export KEY=VALUE
  echo "export $1=${!1}" >>$FILE_NAME
}

store_options() {
  ((OPTION_COUNTER--)) # option counter is [last option number] + 1
  while ((OPTION_COUNTER >= 1)); do
    store_var "OPTION_TOKEN_ADDRESS_${OPTION_COUNTER}"
    ((OPTION_COUNTER--))
  done
}

# clear/create the vars file
echo "" >$FILE_NAME

echo "Initialising..."

MAIN_OUTPUT=$(starknet deploy --contract /carmine/build/amm.json --no_wallet --salt $SALT)

echo "Deployed main contract..."

[[ $MAIN_OUTPUT =~ ([a-z0-9]{66}) ]] && export MAIN_CONTRACT_ADDRESS=${BASH_REMATCH[0]}

LPTOKEN_OUTPUT=$(starknet deploy --contract ./build/lptoken.json --no_wallet --salt $SALT --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS --network alpha-goerli)

[[ $LPTOKEN_OUTPUT =~ ([a-z0-9]{66}) ]] && export LPTOKEN_CONTRACT_ADDRESS=${BASH_REMATCH[0]}

echo "Deployed lptoken..."

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_lptoken --inputs $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $LPTOKEN_CONTRACT_ADDRESS

starknet invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0x1bc16d674ec80000 0

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function deposit_liquidity --inputs $ETH_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE 0x1bc16d674ec80000 0

echo "Deposited liquidity..."

add_option 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $STRIKE_PRICE $MATURITY_1 $OPTION_SIDE_LONG

echo "Deployed first option..."

add_option 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE 3228180212899171532800 $MATURITY_1 $OPTION_SIDE_LONG

add_option 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE 3689348814741910323200 $MATURITY_1 $OPTION_SIDE_LONG

add_option 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE 3804640965202595020800 $MATURITY_1 $OPTION_SIDE_LONG

TEST_BALANCE=$(starknet call --address $OPTION_TOKEN_ADDRESS_1 --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS)

echo "Test option balance is $TEST_BALANCE"

echo "Storing ENV VARS"

store_var "MAIN_CONTRACT_ADDRESS"
store_var "LPTOKEN_CONTRACT_ADDRESS"
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
store_var "STARKNET_CHAIN_ID"
store_var "SALT"
store_var "STARKNET_NETWORK_ID"
store_options
# GATEWAY is different here and outside - gotta store it manually
echo "export STARKNET_FEEDER_GATEWAY_URL=http://localhost:80" >>$FILE_NAME
echo "export STARKNET_GATEWAY_URL=http://localhost:80" >>$FILE_NAME

echo "Done! Use ENV VARS from \"${FILE_NAME}\""

exec "$@"
