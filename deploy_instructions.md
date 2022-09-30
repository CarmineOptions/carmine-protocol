All the export values are manually set and might differ. Same txhashes, addresses,...


# RUN DEVNET
```
sudo docker run --network host shardlabs/starknet-devnet
```
Devnet account
```
    Account #0
    Address: 0x6d619877cb82355238fdc9506b99440d4456f3235c5cd412f9448c8dce69501
    Public key: 0x4e68d92816227d207127c80427d86d069b63ed67218a5b86de2912d2f3dd2e7
    Private key: 0x12dc9fbf6e4456f6f5314dbacba798d3
```
```
export ACCOUNT_0_ADDRESS="0x6d619877cb82355238fdc9506b99440d4456f3235c5cd412f9448c8dce69501"
export ACCOUNT_0_PUBLIC="0x4e68d92816227d207127c80427d86d069b63ed67218a5b86de2912d2f3dd2e7"
export ACCOUNT_0_PRIVATE="0x12dc9fbf6e4456f6f5314dbacba798d3"

export ETH_ADDRESS="0x62230ea046a9a5fbc261ac77d03c8d41e5d442db2284587570ab46455fd2488"
export FAKE_USD_ADDRESS = "456"
export STARKNET_WALLET=starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount
```


# DEPLOY AMM

```
protostar deploy ./build/amm.json --salt 666 --gateway-url "http://127.0.0.1:5050/" --chain-id 1 --inputs $ACCOUNT_0_ADDRESS
```
```                                                         
    Contract address: 0x02f23c067cd535b2b615192c4d7736cc9056e1f4e25866509aa7fb8c3fe7e84e
    Transaction hash: 0x028112ed4d2d7f0ba1f9edde590ad2e1470bf3f5c479b2e746641871998547fe
```

Test that the transaction went through
```
starknet tx_status --hash 0x028112ed4d2d7f0ba1f9edde590ad2e1470bf3f5c479b2e746641871998547fe --feeder_gateway_url "http://127.0.0.1:5050/"
```

Export address of the contract
```
export MAIN_CONTRACT_ADDRESS="0x005e949455800d4c9cc9733eef3fef2addad72c78f1633079d441fe4479679aa"
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
    Contract address: 0x01c63f342fed14eda286ad17f0095e13c178eecbcc8318af463991909adf5dec
    Transaction hash: 0x06fbf13d508c35aed0b8d7e2b04815414f8cae323f64672d92345004f2994732
```

Test that the transaction was received
```
starknet tx_status --hash 0x06fbf13d508c35aed0b8d7e2b04815414f8cae323f64672d92345004f2994732 --feeder_gateway_url "http://127.0.0.1:5050/"
```

export address of the lptoken
```
export LPTOKEN_CONTRACT_ADDRESS="0x0640b9f86b0266acd648ec70c0f2f451b7b031126cf247a6b9cfc2f235e72667"
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

# SEND WETH TO POOL

Get balance of LP tokens on `$ACCOUNT_0_ADDRESS` account.
```
curl http://127.0.0.1:5050/account_balance?address=$ACCOUNT_0_ADDRESS
```
or with for specific token (lptoken)
```
starknet call --address $LPTOKEN_CONTRACT_ADDRESS --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```


    pooled_token_addr: Address,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    lp_token_amount: Math64x61_


```
starknet invoke --address $LPTOKEN_CONTRACT_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0x2000000000000000 0 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function deposit_liquidity --inputs $LPTOKEN_CONTRACT_ADDRESS $ETH_ADDRESS $ETH_ADDRESS 0 10 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
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
Check volatility - should return 0xc8000000000000000 (=100 in hex Math64x61)
```
starknet call --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function get_pool_volatility --feeder_gateway_url "http://127.0.0.1:5050/" --inputs $LPTOKEN_CONTRACT_ADDRESS 1664456400
```


