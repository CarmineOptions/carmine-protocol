# Deploy Dev contract

```
# wallet address
export ACCOUNT_0_ADDRESS=0x3f47b0187bcdde504e83f39a31900207712e0383ee1ac3687eea5af4a02252

export ETH_ADDRESS=0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7  # goerli address
export USD_ADDRESS=0x5a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426  # goerli address
export STARKNET_WALLET=starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount


export MAIN_CONTRACT_ADDRESS=0x05cade694670f80dca1195c77766b643dce01f511eca2b7250ef113b57b994ec

export LPTOKEN_CONTRACT_ADDRESS_CALL=0x0149a0249403aa85859297ac2e3c96b7ca38f2b36d7a34212dcfbc92e8d66eb1
export LPTOKEN_CONTRACT_ADDRESS_PUT=0x077868613647e04cfa11593f628598e93071d52ca05f1e89a70add4bb3470897

export OPTION_TYPE_CALL=0
export OPTION_TYPE_PUT=1
export STRIKE_PRICE=2997595911977802137600 # 1300 * 2**61
export MATURITY_3=1672358399
export OPTION_SIDE_LONG=0
export OPTION_SIDE_SHORT=1
export INITIAL_VOLATILITY=230584300921369395200
```


Available options (including expired ones)
| Side  | Maturity   | Strike  | Quote token address  | Base token address  | Call/Put  | Option token address  |
|-------|------------|---------|----------------------|---------------------|-----------|-----------------------|
| Long  | 1672358399 | 1300    | $USD_ADDRESS         | $ETH_ADDRESS        | Call      | 0x027a1f07ee93043f7668efa54b3618feaf86a2a31a2d735b768feb9e95644a02 |
| Short | 1672358399 | 1300    | $USD_ADDRESS         | $ETH_ADDRESS        | Call      | 0x07faceb4ace680db47f8853ed76b84406b4da9b79acbf4ce9060fd554d2bab3e |
| Long  | 1672358399 | 1300    | $USD_ADDRESS         | $ETH_ADDRESS        | Put       | 0x078781ac3d318137e9fe89d40a8e43007875cc14cbd8f02a9f6d1537bd6c2d5d |
| Short | 1672358399 | 1300    | $USD_ADDRESS         | $ETH_ADDRESS        | Put       | 0x048dcbafd343b05a4df8e22202fcb67632f0994da9a7d8b76db9de66e7506818 |



### tx status
starknet tx_status --network alpha-goerli --hash 0xecc9a5f4fb91ea5b4c5e6b6ab27bc784085ccd8429bea7e9b1ad50ffe0ef24


### Deploy the AMM

Declare the AMM
```
protostar declare ./build/amm.json --network testnet
```
Export the returned hash
```
export AMM_HASH=0x02e15abd48022a49c0a8deb1415ab0af9538d0bb2b89cda3a6ecd9a33d6c1d74
```
Declare the proxy contract
```
protostar declare ./build/proxy.json --network testnet
export PROXY_HASH=0x01067c8f4aa8f7d6380cc1b633551e2a516d69ad3de08af1b3d82e111b4feda4
```
Deploy the PROXY
```
starknet deploy --network alpha-goerli --input $AMM_HASH 0 0 --class_hash $PROXY_HASH
```
export the main contract address
```
export MAIN_CONTRACT_ADDRESS=0x05cade694670f80dca1195c77766b643dce01f511eca2b7250ef113b57b994ec
```
Specify the admin of the contract
```
starknet invoke --network alpha-goerli --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function initializer --input $ACCOUNT_0_ADDRESS
```

### Upgrade AMM

```
export MAIN_CONTRACT_ADDRESS=0x05cade694670f80dca1195c77766b643dce01f511eca2b7250ef113b57b994ec
protostar declare ./build/amm.json --network testnet

export NEW_AMM_HASH=

starknet invoke --network alpha-goerli --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function upgrade --input $NEW_AMM_HASH --max_fee 415160854059520000000
```

### Deploy call lptoken

Deploying lptoken and adding it to the AMM is equivalent to creating new pool!

```
protostar declare ./build/lptoken.json --network testnet
export LPTOKEN_CONTRACT_CALL_HASH=0x07689467492f2ec8984763a1f149e37edbffc667b3a38a1739f781869508e905
```
```
starknet deploy --network alpha-goerli --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS --class_hash $LPTOKEN_CONTRACT_CALL_HASH
export LPTOKEN_CONTRACT_ADDRESS_CALL=0x0149a0249403aa85859297ac2e3c96b7ca38f2b36d7a34212dcfbc92e8d66eb1
```

### Deploy put lptoken

Deploying lptoken and adding it to the AMM is equivalent to creating new pool!

```
protostar declare ./build/lptoken.json --network testnet
export LPTOKEN_CONTRACT_PUT_HASH=0x07689467492f2ec8984763a1f149e37edbffc667b3a38a1739f781869508e905
```
```
starknet deploy --network alpha-goerli --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS --class_hash $LPTOKEN_CONTRACT_PUT_HASH
export LPTOKEN_CONTRACT_ADDRESS_PUT=0x077868613647e04cfa11593f628598e93071d52ca05f1e89a70add4bb3470897
```

### Add BOTH lptokens to the AMM

Add the lptoken
```
starknet invoke --network alpha-goerli --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_lptoken --inputs $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE_CALL $LPTOKEN_CONTRACT_ADDRESS_CALL

starknet invoke --network alpha-goerli --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_lptoken --inputs $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE_PUT $LPTOKEN_CONTRACT_ADDRESS_PUT
```

### Deploy options

use the scripts/deploy_and_add_option.sh




## Random stuff
-----------------

starknet call --network alpha-goerli --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function get_all_options --inputs $LPTOKEN_CONTRACT_ADDRESS_CALL

get_all_options 


-----------------

starknet call --gateway_url=http://alpha4-2.starknet.io --feeder_gateway_url=http://alpha4-2.starknet.io --chain_id=0x534e5f474f45524c49 --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function get_all_options --inputs $LPTOKEN_CONTRACT_ADDRESS_CALL

starknet call --gateway_url=http://alpha4-2.starknet.io --feeder_gateway_url=http://alpha4-2.starknet.io --chain_id=0x534e5f474f45524c49 --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function get_all_non_expired_options_with_premia --inputs $LPTOKEN_CONTRACT_ADDRESS_CALL

starknet call --gateway_url=http://alpha4-2.starknet.io --feeder_gateway_url=http://alpha4-2.starknet.io --chain_id=0x534e5f474f45524c49 --address 0x005a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426 --abi ./build/lptoken_abi.json --function balanceOf --inputs 0x01159a8E3f50Bf7919EB3684d08e91E28e014013E66AC5e5b3EA752A47426AF4

starknet call --gateway_url=http://alpha4-2.starknet.io --feeder_gateway_url=http://alpha4-2.starknet.io --chain_id=0x534e5f474f45524c49 --address 0x077778c5960c149272c2bc989546ad9595d4427bc8fa8edd0d3ead075e7d871d --abi ./build/lptoken_abi.json --function balanceOf --inputs 0x01159a8E3f50Bf7919EB3684d08e91E28e014013E66AC5e5b3EA752A47426AF4

