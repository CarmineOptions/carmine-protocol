All the export values are manually set and might differ. Same txhashes, addresses,...


# RUN DEVNET
```
sudo docker run --network host shardlabs/starknet-devnet
```

Seed: 2340797347

Devnet account
```
    Address: 0x5a9ff56db4fc6fd4494cf98e8a4b67b3a294bc45109ed9f68dcfe159de2562d
    Public key: 0x4125a3a6b20fe4cd11d65f9f8ba4285644a16063d9a2eb1bf5abcf476c2de14
    Private key: 0x45099ebb98a9fd8d8ae5fdca1f37c55c
```
```
export ACCOUNT_0_ADDRESS="0x5a9ff56db4fc6fd4494cf98e8a4b67b3a294bc45109ed9f68dcfe159de2562d"
export ACCOUNT_0_PUBLIC="0x4125a3a6b20fe4cd11d65f9f8ba4285644a16063d9a2eb1bf5abcf476c2de14"
export ACCOUNT_0_PRIVATE="0x45099ebb98a9fd8d8ae5fdca1f37c55c"

Also update the account values in `starknet_open_zeppelin_accounts.json`

export ETH_ADDRESS="0x62230ea046a9a5fbc261ac77d03c8d41e5d442db2284587570ab46455fd2488"
export FAKE_USD_ADDRESS="456"
export STARKNET_WALLET=starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount


export STRIKE_PRICE=3458764513820540928000 # 1500 * 2**61
export MATURITY_1=1664823300
```


# DEPLOY AMM

```
protostar deploy ./build/amm.json --salt 666 --gateway-url "http://127.0.0.1:5050/" --chain-id 1
```
```                                                         
    Contract address: 0x01359224b5897227288405a5e55ee555884ff15a0fbf736fa92f08497d5920fb
    Transaction hash: 0x028112ed4d2d7f0ba1f9edde590ad2e1470bf3f5c479b2e746641871998547fe
```

Test that the transaction went through
```
starknet tx_status --hash 0x028112ed4d2d7f0ba1f9edde590ad2e1470bf3f5c479b2e746641871998547fe --feeder_gateway_url "http://127.0.0.1:5050/"
```

Export address of the contract
```
export MAIN_CONTRACT_ADDRESS="0x06b695bf77c58ae0c41c7c520485d8b8ffd9927bc7922ee9ee317561fbc2b969"
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
protostar deploy ./build/lptoken.json --gateway-url "http://127.0.0.1:5050/" --chain-id 1 --salt 777 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS
```
```
    Contract address: 0x02309c8c2a3ffc464520ddb3e60a0564103b82a8ede38d212e7093e74a93f355
    Transaction hash: 0x06fbf13d508c35aed0b8d7e2b04815414f8cae323f64672d92345004f2994732
```

Test that the transaction was received
```
starknet tx_status --hash 0x06fbf13d508c35aed0b8d7e2b04815414f8cae323f64672d92345004f2994732 --feeder_gateway_url "http://127.0.0.1:5050/"
```

export address of the lptoken
```
export LPTOKEN_CONTRACT_ADDRESS="0x0557ec5b3d56a6abd33e5bd6da166b05cc8d90e61e52d5f5a4f22713dbcb119c"
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
    quote_token_address = $FAKE_USD_ADDRESS, # will change it to something more reasonable
    base_token_address = $ETH_ADDRESS,
    option_type = 0, # call
    lptoken_address = $LPTOKEN_CONTRACT_ADDRESS
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_lptoken --inputs $FAKE_USD_ADDRESS $ETH_ADDRESS 0 $LPTOKEN_CONTRACT_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
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

# PROVIDE LIQUIDITY (ETH) TO POOL

Get balance of LP tokens on `$ACCOUNT_0_ADDRESS` account. For specific LP token (lptoken)
```
starknet call --address $LPTOKEN_CONTRACT_ADDRESS --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```
Same for ETH
```
starknet call --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```


Approve the pool to transact the tokens from the account in size of 2ETH (2 * 10**18 -> 0x1bc16d674ec80000)
```
starknet invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0x1bc16d674ec80000 0 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```
Account is depositing 2ETH
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function deposit_liquidity --inputs $ETH_ADDRESS $FAKE_USD_ADDRESS $ETH_ADDRESS 0 0x1bc16d674ec80000 0 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```


# WITHDRAW LIQUIDITY (ETH) FROM POOL

Look at current balance of LP token (should be 0x1bc16d674ec80000 if the above was called)
```
starknet call --address $LPTOKEN_CONTRACT_ADDRESS --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```
```
starknet call --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```

Withdraw liquidity in size of half of the LP tokens (1*10**18 = 0xde0b6b3a7640000).
Balance of account should decrease by this size in terms of LP token and increase by 1 ETH adjusted for fees (since basically nothing has happened in the pool yet).
```
starknet invoke --address $LPTOKEN_CONTRACT_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0xde0b6b3a7640000 0 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function withdraw_liquidity --inputs $ETH_ADDRESS $FAKE_USD_ADDRESS $ETH_ADDRESS 0 0xde0b6b3a7640000 0 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```

Check the balances after the capital was withdrawned.
```
starknet call --address $LPTOKEN_CONTRACT_ADDRESS --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```
```
starknet call --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```


# DEPLOY OPTION TOKEN

        name = 111,
        symbol = 11,
        decimals = 18,
        initial_supply = 0 0,
        recipient = $ACCOUNT_0_ADDRESS,
        owner = $MAIN_CONTRACT_ADDRESS,
        quote_token_address = $FAKE_USD_ADDRESS, # will change it to something more reasonable
        base_token_address = $ETH_ADDRESS,
        option_type = 0,  # call
        strike_price = $STRIKE_PRICE
        maturity = $MATURITY_1
        side = 0, # long
```
protostar deploy ./build/option_token.json --gateway-url "http://127.0.0.1:5050/" --chain-id 1 --salt 666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $FAKE_USD_ADDRESS $ETH_ADDRESS 0 $STRIKE_PRICE $MATURITY_1 0
```
```
	Contract address: 0x007a4c35ea9d27303dbffaeeb64cb71de68f42480e5f8957464ff60ca5006c39
	Transaction hash: 0x034c1877848d3741f608e8f3ac1b4028b23faf3f3f4ac4b05046f817f211e86f
```
```
export OPTION_TOKEN_ADDRESS_1="0x0693f54a327c14e1ae3fb5c96cb802180ecf9e566fefeeab812cfeafa4199499"
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
export STRIKE_PRICE=3458764513820540928000 # 1500 * 2**61
export MATURITY_1=1664742600

    option_side = 0,
    maturity = $MATURITY_1
    strike_price: $STRIKE_PRICE
    quote_token_address = $FAKE_USD_ADDRESS, # will change it to something more reasonable
    base_token_address = $ETH_ADDRESS,
    option_type = 0, # call
    lptoken_address = $LPTOKEN_CONTRACT_ADDRESS,
    option_token_address_ = $OPTION_TOKEN_ADDRESS_1,
    initial_volatility = 230584300921369395200, # 100 * 2**61

```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs 0 $MATURITY_1 $STRIKE_PRICE $FAKE_USD_ADDRESS $ETH_ADDRESS 0 $LPTOKEN_CONTRACT_ADDRESS $OPTION_TOKEN_ADDRESS_1 230584300921369395200 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```
Check volatility - should return 0xc8000000000000000 (=100 in hex Math64x61)
```
starknet call --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function get_pool_volatility --feeder_gateway_url "http://127.0.0.1:5050/" --inputs $LPTOKEN_CONTRACT_ADDRESS $MATURITY_1
```


# TRADE - BUY OPTION

    option_type = 0, # call
    strike_price = $STRIKE_PRICE
    maturity = $MATURITY_1,
    option_side = 0, # long
    option_size = 230584300921369395 (=2**61 / 10 -> 0.1ETH) 
    quote_token_address = $FAKE_USD_ADDRESS, # will change it to something more reasonable
    base_token_address = $ETH_ADDRESS,
    open_position = 0


Notice that much higher volume is approved than will be actually paid for in premia and fees.
```
starknet invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0x2000000000000000 0 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```

```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function trade_open --inputs 0 $STRIKE_PRICE $MATURITY_1 0 230584300921369395 $FAKE_USD_ADDRESS $ETH_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```

```
starknet call --address $OPTION_TOKEN_ADDRESS_1 --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```


# TRADE - CLOSE HALF OF PREVIOUSLY BOUGHT OPTION

At this point, there should be position in lptoken = 0.1 (0.1*10**18). This invoke burns half of it and pays premia to $ACCOUNT_0_ADDRESS.

    option_type = 0,
    strike_price = $STRIKE_PRICE,
    maturity = $MATURITY_1,
    option_side = OptionSide,
    option_size = 115292150460684697,
    quote_token_address = $FAKE_USD_ADDRESS,
    base_token_address = $ETH_ADDRESS,

```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function trade_close --inputs 0 $STRIKE_PRICE $MATURITY_1 0 115292150460684697 $FAKE_USD_ADDRESS $ETH_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```

Check that the position of $ACCOUNT_0_ADDRESS has decreased
```
starknet call --address $OPTION_TOKEN_ADDRESS_1 --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```


# TRADE - SETTLE (EXPIRE) PREVIOUSLY BOUGHT OPTION


    option_type = 0,
    strike_price = $STRIKE_PRICE,
    maturity = $MATURITY_1,
    option_side = 0,
    option_size = 230584300921369395,
    quote_token_address = $FAKE_USD_ADDRESS,
    base_token_address = $ETH_ADDRESS,

```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function trade_settle --inputs 0 $STRIKE_PRICE $MATURITY_1 0 230584300921369395 $FAKE_USD_ADDRESS $ETH_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```

```
starknet call --address $OPTION_TOKEN_ADDRESS_1 --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli
```



# ############################################################################################

# DEPLOY ON DEVNET

protostar deploy ./build/amm.json --salt 666 --gateway-url "http://127.0.0.1:5050/" --chain-id 1

export MAIN_CONTRACT_ADDRESS="

protostar deploy ./build/lptoken.json --gateway-url "http://127.0.0.1:5050/" --chain-id 1 --salt 777 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS

export LPTOKEN_CONTRACT_ADDRESS="

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_lptoken --inputs $FAKE_USD_ADDRESS $ETH_ADDRESS 0 $LPTOKEN_CONTRACT_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli

starknet invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0x1bc16d674ec80000 0 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function deposit_liquidity --inputs $ETH_ADDRESS $FAKE_USD_ADDRESS $ETH_ADDRESS 0 0x1bc16d674ec80000 0 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli

protostar deploy ./build/option_token.json --gateway-url "http://127.0.0.1:5050/" --chain-id 1 --salt 666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $FAKE_USD_ADDRESS $ETH_ADDRESS 0 $STRIKE_PRICE $MATURITY_1 0

export OPTION_TOKEN_ADDRESS_1="

protostar deploy ./build/option_token.json --gateway-url "http://127.0.0.1:5050/" --chain-id 1 --salt 666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $FAKE_USD_ADDRESS $ETH_ADDRESS 0 $STRIKE_PRICE $MATURITY_1 1

export OPTION_TOKEN_ADDRESS_1_opposite="

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs 0 $MATURITY_1 $STRIKE_PRICE $FAKE_USD_ADDRESS $ETH_ADDRESS 0 $LPTOKEN_CONTRACT_ADDRESS $OPTION_TOKEN_ADDRESS_1 230584300921369395200 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs 1 $MATURITY_1 $STRIKE_PRICE $FAKE_USD_ADDRESS $ETH_ADDRESS 0 $LPTOKEN_CONTRACT_ADDRESS $OPTION_TOKEN_ADDRESS_1_opposite 230584300921369395200 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli

starknet invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0x2000000000000000 0 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function trade_open --inputs 0 $STRIKE_PRICE $MATURITY_1 0 230584300921369395 $FAKE_USD_ADDRESS $ETH_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli




!!!! This motherfucker needs opposite side as user (if user is long, pool is short -> use short)
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function expire_option_token_for_pool --inputs $LPTOKEN_CONTRACT_ADDRESS 1 $STRIKE_PRICE $MATURITY_1 --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli


starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function trade_settle --inputs 0 $STRIKE_PRICE $MATURITY_1 0 230584300921369395 $FAKE_USD_ADDRESS $ETH_ADDRESS --gateway_url "http://127.0.0.1:5050/" --feeder_gateway_url "http://127.0.0.1:5050/" --network alpha-goerli


# ############################################################################################

# DEPLOYED


export ACCOUNT_0_ADDRESS=0x0305b9156d9e4cf59f51e1bae7f74456c65f5f2159e9d6780fa8e0a30a44a23f
export USD_ADDRESS="0x005a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426"
export ETH_ADDRESS=0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
export MATURITY_1=1664863200



protostar declare ./build/amm.json --network alpha-goerli
export AMM_HASH=...

starknet deploy --contract ./build/proxy.json --network alpha-goerli --no_wallet --input $AMM_HASH 0 0
export MAIN_CONTRACT_ADDRESS=....

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function initializer --input $ACCOUNT_0_ADDRESS
-> input here specifies the admin of the proxy contract
<!-- export MAIN_CONTRACT_ADDRESS="0x036912baeb88d2c34ee8f9081bed7f6044d8fc40ccc82323e87887ed1e1509ea" -->

protostar deploy ./build/lptoken.json --network alpha-goerli --salt 778 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS

export LPTOKEN_CONTRACT_ADDRESS="0x07fa635eafc89f99ca734fdb6c5e6108a294f6503ea47ad91276cdc370cc2795"

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_lptoken --inputs $USD_ADDRESS $ETH_ADDRESS 0 $LPTOKEN_CONTRACT_ADDRESS --network alpha-goerli

starknet invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0x5AF3107A4000 0 --network alpha-goerli

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function deposit_liquidity --inputs $ETH_ADDRESS $USD_ADDRESS $ETH_ADDRESS 0 0x5AF3107A4000 0 --network alpha-goerli

protostar deploy ./build/option_token.json --network alpha-goerli --salt 667 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $USD_ADDRESS $ETH_ADDRESS 0 $STRIKE_PRICE $MATURITY_1 0

export OPTION_TOKEN_ADDRESS_1="0x041ee130e44a21a5c612f2e93d6b7e22594f5a7b22894f2f291ef520ac96d376"

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs 0 $MATURITY_1 $STRIKE_PRICE $USD_ADDRESS $ETH_ADDRESS 0 $LPTOKEN_CONTRACT_ADDRESS $OPTION_TOKEN_ADDRESS_1 230584300921369395200 --network alpha-goerli




starknet invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0xE8D4A51000 0 --network alpha-goerli

starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function trade_open --inputs 0 $STRIKE_PRICE $MATURITY_1 0 2305843009200 $USD_ADDRESS $ETH_ADDRESS --network alpha-goerli

For upgrades:
    starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function initializer --input $NEW_AMM_HASH

For changing admin:
    starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function setAdmin --input $NEW_ADMIN_ADDRESS
