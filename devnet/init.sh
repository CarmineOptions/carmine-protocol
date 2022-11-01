#!/bin/bash

echo "Initialising..."

MAIN_OUTPUT=$(starknet --chain_id 0x534e5f474f45524c49 --network_id devnet --gateway_url http://devnet:5050/ --feeder_gateway_url http://devnet:5050/ deploy --contract /carmine/build/amm.json --no_wallet --salt 0x666)

echo "Deployed main contract"

echo $MAIN_OUTPUT

[[ $MAIN_OUTPUT =~ ([a-z0-9]{66}) ]] && export MAIN_CONTRACT_ADDRESS=${BASH_REMATCH[0]}

echo $MAIN_CONTRACT_ADDRESS

LPTOKEN_OUTPUT=$(starknet --chain_id 0x534e5f474f45524c49 --network_id devnet --gateway_url http://devnet:5050/ --feeder_gateway_url http://devnet:5050/ deploy --contract ./build/lptoken.json --no_wallet --salt 0x666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS --network alpha-goerli)

[[ $LPTOKEN_OUTPUT =~ ([a-z0-9]{66}) ]] && export LPTOKEN_CONTRACT_ADDRESS=${BASH_REMATCH[0]}

echo "Deployed lptoken"

echo $LPTOKEN_OUTPUT

echo $LPTOKEN_CONTRACT_ADDRESS

echo "Depositing liquidity..."

starknet --chain_id 0x534e5f474f45524c49 --network_id devnet --gateway_url http://devnet:5050/ --feeder_gateway_url http://devnet:5050/ invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_lptoken --inputs $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $LPTOKEN_CONTRACT_ADDRESS

starknet --chain_id 0x534e5f474f45524c49 --network_id devnet --gateway_url http://devnet:5050/ --feeder_gateway_url http://devnet:5050/ invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0x1bc16d674ec80000 0

starknet --chain_id 0x534e5f474f45524c49 --network_id devnet --gateway_url http://devnet:5050/ --feeder_gateway_url http://devnet:5050/ invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function deposit_liquidity --inputs $ETH_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE 0x1bc16d674ec80000 0

echo "Deposited liquidity"

OPTION_1_OUT=$(starknet --chain_id 0x534e5f474f45524c49 --network_id devnet --gateway_url http://devnet:5050/ --feeder_gateway_url http://devnet:5050/ deploy --contract ./build/option_token.json --no_wallet --salt 0x666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $STRIKE_PRICE $MATURITY_1 $OPTION_SIDE_LONG)

echo "OPTION 1 deployed: $OPTION_1_OUT"

[[ $OPTION_1_OUT =~ ([a-z0-9]{66}) ]] && export OPTION_TOKEN_ADDRESS_1=${BASH_REMATCH[0]}

starknet --chain_id 0x534e5f474f45524c49 --network_id devnet --gateway_url http://devnet:5050/ --feeder_gateway_url http://devnet:5050/ invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs $OPTION_SIDE_LONG $MATURITY_1 $STRIKE_PRICE $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $LPTOKEN_CONTRACT_ADDRESS $OPTION_TOKEN_ADDRESS_1 $INITIAL_VOLATILITY

TEST_BALANCE=$(starknet --chain_id 0x534e5f474f45524c49 --network_id devnet --gateway_url http://devnet:5050/ --feeder_gateway_url http://devnet:5050/ call --address $OPTION_TOKEN_ADDRESS_1 --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS)

echo "test balance: $TEST_BALANCE"
echo ""
echo "export MAIN_CONTRACT_ADDRESS=${MAIN_CONTRACT_ADDRESS}"
echo "export LPTOKEN_CONTRACT_ADDRESS=${LPTOKEN_CONTRACT_ADDRESS}"
echo "export OPTION_TOKEN_ADDRESS_1=${OPTION_TOKEN_ADDRESS_1}"

echo $(export -p)

echo $(export -p) >>_current_vars.env

exec "$@"
