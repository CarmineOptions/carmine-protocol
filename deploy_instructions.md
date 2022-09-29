All the export values are manually set and might differ. Same txhashes, addresses,...


# RUN DEVNET
```
sudo docker run --network host shardlabs/starknet-devnet
```
Devnet account
```
	Account #0
    Address: 0x318b8d6024408eb03cba34ccd7102a92461ad99491cfd5781bf6099df30523f
    Public key: 0x3ca6eb148b73abd8863cd8db73f8c4ce2bcc313415cc0c09c96a51233f3107e
    Private key: 0x52938bc139b72088bf8d0ec817fc6ecb
```
```
export ACCOUNT_0_ADDRESS="0x318b8d6024408eb03cba34ccd7102a92461ad99491cfd5781bf6099df30523f"
export ACCOUNT_0_PUBLIC="0x3ca6eb148b73abd8863cd8db73f8c4ce2bcc313415cc0c09c96a51233f3107e"
export ACCOUNT_0_PRIVATE="0x52938bc139b72088bf8d0ec817fc6ecb"

```


# DEPLOY AMM

```
protostar deploy ./build/amm.json --salt 666 --gateway-url "http://127.0.0.1:5050/" --chain-id 1 --inputs $ACCOUNT_0_ADDRESS
```
```                                                         
    Contract address: 0x000602dea9323a603f1933bf1174543265bac5861faac0a7ea1d0bbea126331d
    Transaction hash: 0x004c59b19366f61bc10fe3bad36c4fa7b5ca8b0c1bbbeaf03f7a7ea900362ee9
```

Test that the transaction went through
```
starknet tx_status --hash 0x004c59b19366f61bc10fe3bad36c4fa7b5ca8b0c1bbbeaf03f7a7ea900362ee9 --feeder_gateway_url "http://127.0.0.1:5050/"
```

Export address of the contract
```
export MAIN_CONTRACT_ADDRESS="0x000602dea9323a603f1933bf1174543265bac5861faac0a7ea1d0bbea126331d"
```

Validate owner address - should be equal to $ACCOUNT_0_ADDRESS
```
starknet call --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function owner --feeder_gateway_url "http://127.0.0.1:5050/"
```


# DEPLOY LPTOKEN

        name = 111,
        symbol = 11,
        decimals = 18,
        initial_supply = 0 0,
        recipient = $ACCOUNT_0_ADDRESS,
        owner = $MAIN_CONTRACT_ADDRESS,
```
protostar deploy ./build/lptoken.json --gateway-url "http://127.0.0.1:5050/" --chain-id 1 --salt 666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS
```
```
    Contract address: 0x0234f614ce4e224286be4698162807f259e979cabe83c97a84aa67df747f6b3c
    Transaction hash: 0x014d37c2716942d62fb22bd6927a8559cda79fc3f78a2b5c14a450cd3b376506
```

Test that the transaction was received
```
starknet tx_status --hash 0x014d37c2716942d62fb22bd6927a8559cda79fc3f78a2b5c14a450cd3b376506 --feeder_gateway_url "http://127.0.0.1:5050/"
```

export address of the lptoken
```
export LPTOKEN_CONTRACT_ADDRESS="0x0234f614ce4e224286be4698162807f259e979cabe83c97a84aa67df747f6b3c"
```

Have a look at symbol name
```
starknet call --address $LPTOKEN_CONTRACT_ADDRESS --abi ./build/lptoken_abi.json --function symbol --feeder_gateway_url "http://127.0.0.1:5050/"
```
```
	11
```


# ADD LP TOKEN TO THE AMM

AMM address is `$MAIN_CONTRACT_ADDRESS` and address of the lptoken is `$LPTOKEN_CONTRACT_ADDRESS`.

Params:
    quote_token_address = $ETH_ADDRESS, # will change it to something more reasonable
    base_token_address = $ETH_ADDRESS,
    option_type = 0, # call
    lptoken_address = $LPTOKEN_CONTRACT_ADDRESS
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_lptoken --inputs $ETH_ADDRESS $ETH_ADDRESS 0 $LPTOKEN_CONTRACT_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```
Response from the invoke 
```
    Contract address: 0x000602dea9323a603f1933bf1174543265bac5861faac0a7ea1d0bbea126331d
    Transaction hash: 0x7bc23279a6992aa77da61fe125f7b7d144e9040b8ec05dc2da48c6ce5c26156
```

Look at `lptoken_addr_for_given_pooled_token` that the lptoken address (=$LPTOKEN_CONTRACT_ADDRESS) was written
```
starknet call --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function get_lptoken_address_for_given_option --inputs $ETH_ADDRESS $ETH_ADDRESS 0 --feeder_gateway_url "http://127.0.0.1:5050/"
```


# DEPLOY OPTION TOKEN

        name = 111,
        symbol = 11,
        decimals = 18,
        initial_supply = 0 0,
        recipient = $ACCOUNT_0_ADDRESS,
        owner = $MAIN_CONTRACT_ADDRESS,
        underlying_asset_address = 0,
        option_type = 0,  # call
        strike_price = 3458764513820540928000, # 1500 * 2 **61
        maturity = 1664456400, # Thu Sep 29 2022 13:00:00 GMT+0000 -> Thu Sep 29 2022 15:00:00 GMT+0200 (CEST)
        side = 0, # long
```
protostar deploy ./build/option_token.json --gateway-url "http://127.0.0.1:5050/" --chain-id 1 --salt 666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS 0 0 3458764513820540928000 1664456400 0
```
```
	Contract address: 0x007a4c35ea9d27303dbffaeeb64cb71de68f42480e5f8957464ff60ca5006c39
	Transaction hash: 0x034c1877848d3741f608e8f3ac1b4028b23faf3f3f4ac4b05046f817f211e86f
```
```
export OPTION_TOKEN_ADDRESS_1="0x007a4c35ea9d27303dbffaeeb64cb71de68f42480e5f8957464ff60ca5006c39"
```
Test that the transaction was accepted
```
starknet tx_status --hash 0x034c1877848d3741f608e8f3ac1b4028b23faf3f3f4ac4b05046f817f211e86f --feeder_gateway_url "http://127.0.0.1:5050/"
```
```
	{
	    "block_hash": "0x264c3a930af220d32948481d6d783705ea3e8b30c9acb36c69fd886670469e8",
	    "tx_status": "ACCEPTED_ON_L2"
	}
```


# ADD OPTION TOKEN TO LIQUIDITY POOL

    option_side = 0,
    maturity = 1664456400, # Thu Sep 29 2022 13:00:00 GMT+0000 -> Thu Sep 29 2022 15:00:00 GMT+0200 (CEST)
    strike_price: 3458764513820540928000, # 1500 * 2 **61
    quote_token_address = $ETH_ADDRESS,
    base_token_address = $ETH_ADDRESS,
    option_type = 0, # call
    lptoken_address = $LPTOKEN_CONTRACT_ADDRESS,
    option_token_address_ = $OPTION_TOKEN_ADDRESS_1,
    initial_volatility = 230584300921369395200, # 100 * 2**61

```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs 0 1664456400 3458764513820540928000 $ETH_ADDRESS $ETH_ADDRESS 0 $LPTOKEN_CONTRACT_ADDRESS $OPTION_TOKEN_ADDRESS_1 230584300921369395200 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```
