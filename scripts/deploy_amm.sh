export STARKNET_WALLET=starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount
export MAIN_CONTRACT_ADDRESS=0x05cade694670f80dca1195c77766b643dce01f511eca2b7250ef113b57b994ec
export PROTOSTAR_ACCOUNT_PRIVATE_KEY= # ADD private key from starknet_open_zeppelin_accounts.json

protostar build
protostar declare ./build/amm.json --network testnet --account-address 0x3f47b0187bcdde504e83f39a31900207712e0383ee1ac3687eea5af4a02252 --max-fee 25000000000

export NEW_AMM_HASH=0x0306cc26a48407d8ce6a2529f754ce382fa63d1a0688e66e0f64bbcbdab18265 # ADD HASH FROM

starknet invoke --network alpha-goerli --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function upgrade --input $NEW_AMM_HASH --max_fee 415160854059520000000

echo "Don't forget to add the new abis to abi/"