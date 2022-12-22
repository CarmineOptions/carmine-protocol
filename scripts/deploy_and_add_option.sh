#!/bin/bash
# This script deploys a new option and adds it to the AM

export STARKNET_NETWORK=alpha-goerli
export STARKNET_WALLET=starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount
#FEEDER_GATEWAY_URL=https://alpha4-2.starknet.io/feeder_gateway/
FEEDER_GATEWAY_URL=https://alpha4.starknet.io/feeder_gateway/
#GATEWAY_URL=https://alpha4-2.starknet.io/gateway/
GATEWAY_URL=https://alpha4.starknet.io/gateway/
# cp ~/.starknet_accounts/starknet_open_zeppelin_accounts-testnet1.json ~/.starknet_accounts/starknet_open_zeppelin_accounts.json

ADMIN=0x003f47b0187bcdde504e83f39a31900207712e0383ee1ac3687eea5af4a02252 # testnet 1
#ADMIN=0x54beabcdd71b0735edc2cc67e86da69a30c0fed3a91a33bae88244744bba1ed # testnet 2
QUOTE_TOKEN_ADDRESS=159707947995249021625440365289670166666892266109381225273086299925265990694 # testnet 1
BASE_TOKEN_ADDRESS=2087021424722619777119509474943472645767659996348769578120564519014510906823 # testnets both
# AMM_ADDRESS=0x042a7d485171a01b8c38b6b37e0092f0f096e9d3f945c50c77799171916f5a54 # testnet 1
AMM_ADDRESS=0x05cade694670f80dca1195c77766b643dce01f511eca2b7250ef113b57b994ec # testnet 1 dev
#AMM_ADDRESS=0x07e1c9397cc53d1cdf062db6fc8fe5fea9b004e797e4a3e6860ce1090d0586a3 # testnet 2

#LPTOKEN_ADDRESS=86564211892987183020075958831889857811281626806290146628813165299578849650 # testnet1 ETH/USD CALL OR PUT YOU IDIOT??
# LPTOKEN_ADDRESS_CALL=1670491592542153639514933832267888176485402969097374551415059266031357840407 # testnet1 eth/usd call pool
# LPTOKEN_ADDRESS_PUT=86564211892987183020075958831889857811281626806290146628813165299578849650 # testnet1 eth/usd put pool
LPTOKEN_ADDRESS_CALL=0x0149a0249403aa85859297ac2e3c96b7ca38f2b36d7a34212dcfbc92e8d66eb1 # dev testnet1 eth/usd call pool
LPTOKEN_ADDRESS_PUT=0x077868613647e04cfa11593f628598e93071d52ca05f1e89a70add4bb3470897 # dev testnet1 eth/usd put pool
#LPTOKEN_ADDRESS=367852766564488059499954238561392360215903199117051217276115258544759204227 # testnet2 call pool
#LPTOKEN_ADDRESS=2738355697057021849185852497074326827930099024415976588426758511175104190904 # testnet2 put pool
INITIAL_VOLATILITY=230584300921369395200

# ADJUST THESE BEFORE RUNNING

OPTION_TYPE=1
STRIKE_PRICE=2997595911977802137600 # 1300
#STRIKE_PRICE=2767011611056432742400 # 1200
# MATURITY=1671148799 #15th dec
MATURITY=1672358399 # 29th dec
OPTION_SIDE=1
CLASS_HASH=0x0489c4d9adf068ae5198f9bd180450fdf5aceb5e6989a958b8833cb45f1f2b6c # testnet1
#CLASS_HASH=0x0303cbc2300f9b00d77098431703eeae61b4985247856ff13e6d2d0bebbc612a # testnet2, class hash for option token

if [ $OPTION_TYPE == 1 ]; then
    LPTOKEN_ADDRESS=$LPTOKEN_ADDRESS_PUT
else
    LPTOKEN_ADDRESS=$LPTOKEN_ADDRESS_CALL
fi

starknet deploy --gateway_url $GATEWAY_URL --feeder_gateway_url $FEEDER_GATEWAY_URL --inputs 123456789 1234 18 0 0 $AMM_ADDRESS $AMM_ADDRESS $QUOTE_TOKEN_ADDRESS $BASE_TOKEN_ADDRESS $OPTION_TYPE $STRIKE_PRICE $MATURITY $OPTION_SIDE --class_hash $CLASS_HASH

echo "Please paste the contract address and press Enter"
read OPTION_TOKEN_ADDRESS_HEX
echo "Please paste the tx hash and press Enter"
read TXHASH

OPTION_TOKEN_ADDRESS=$(echo $OPTION_TOKEN_ADDRESS_HEX | python scripts/todec.py)
SUCCESS=n
sleep 10
while [ y$SUCCESS != "yy" ]
do
    starknet get_transaction_receipt --feeder_gateway_url $FEEDER_GATEWAY_URL --hash $TXHASH
    echo "Does it look like the transaction was successful? y to continue, Ctrl-C to abort, anything else to keep waiting"
    read SUCCESS
done


starknet invoke --gateway_url $GATEWAY_URL --feeder_gateway_url $FEEDER_GATEWAY_URL --address $AMM_ADDRESS --abi abi/v0.1.10/amm_abi.json --function add_option --inputs $OPTION_SIDE $MATURITY $STRIKE_PRICE $QUOTE_TOKEN_ADDRESS $BASE_TOKEN_ADDRESS $OPTION_TYPE $LPTOKEN_ADDRESS $OPTION_TOKEN_ADDRESS $INITIAL_VOLATILITY --max_fee 2560986752518800
echo "Please paste the tx hash from above here"
read TXHASH
SUCCESS=n
sleep 10
while [ y$SUCCESS != "yy" ]
do
    starknet get_transaction_receipt --feeder_gateway_url $FEEDER_GATEWAY_URL --hash $TXHASH
    echo "Does it look like the transaction was successful? y to continue, Ctrl-C to abort, anything else to keep waiting"
    read SUCCESS
done
