# Carmine Protocol

Carmine options protocol

Options AMM that allows any user to buy and sell options at a fair price.

For crypto funds, traders and investors who need to hedge their portfolios or trade options, this
options AMM will provide a possibility to do so. Different from competitors, this AMM allows for
selling specific options directly.

## Current State

We have an early alpha up and running on testnet, see below for addresses. We don't have a working frontend yet.

## Documentation

High level docs [here](https://carmine-finance.gitbook.io/carmine-options-amm/).
Code docs will be published soon

## Other Links

- [Twitter](https://twitter.com/CarmineOptions)
- [Web](https://carmine.finance)
- [Discord](https://discord.com/invite/uRs7j8w3bX)
- [Docs](https://carmine-finance.gitbook.io/carmine-options-amm/)

## Currently deployed contracts on testnet

```
MAIN_CONTRACT_ADDRESS=0x031bc941e58ee989d346a3e12b2d367228c6317bb9533821ce7a29d487ae12bc
# ETH/USD CALL pool
LPTOKEN_CONTRACT_ADDRESS=0x02733d9218f96aaa5908ec99eff401f5239aa49d8102aae8f4c7f520c5260d5c
# ETH/USD PUT pool
LPTOKEN_CONTRACT_ADDRESS_PUT=0x03f510585d678a03b1a95e20c5b5f13bd0a3dea9e43b0de2b71b81a2e9f1b278

export ETH_ADDRESS=0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7  # goerli address
export USD_ADDRESS=0x5a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426  # goerli address
```
Available options (including expired ones)
| Side  | Maturity   | Strike  | Quote token address  | Base token address  | Call/Put  | Option token address  |
|-------|------------|---------|----------------------|---------------------|-----------|-----------------------|
| Long  | 1664992981 | 1500    | $USD_ADDRESS         | $ETH_ADDRESS        | Call      | 0x304a6f21c609c59201f8f2086e85dcf570edc1379abb01f9a06fd4f7062c42a |
| Long  | 1665511435 | 1500    | $USD_ADDRESS         | $ETH_ADDRESS        | Call      | 0xae002dea00cd617a468a3caafa2832124aed60750b921c1e53ebcb5c3acc46 |
| Short | 1664992981 | 1500    | $USD_ADDRESS         | $ETH_ADDRESS        | Call      | 0x1ff82740cb4a2dfe332e3d1ded3b7fcc1042612cf9d2ae70b0b5ca520c635ea |
| Short | 1665511435 | 1500    | $USD_ADDRESS         | $ETH_ADDRESS        | Call      | 0x0626ebb9d8be8bf3f113780e39b409ba22edc248f7915d39a1b253c9a7614ec9 |
| Long  | 1669849199 | 1500    | $USD_ADDRESS         | $ETH_ADDRESS        | Call      | 0x051cc0a93cf22935493a56959c3f34eda20707cb306949e9da390b2b97120332 |
| Short | 1669849199 | 1500    | $USD_ADDRESS         | $ETH_ADDRESS        | Call      | 0x03385b9a4dc48a8d696c98f11768680b7f57e4e1fc19a0318b4ab676d80f758d |
| Long  | 1669849199 | 1700    | $USD_ADDRESS         | $ETH_ADDRESS        | Call      | 0x06bc44f42f834c6c0e8c5e225a638362bc778152bd451d62cef8379addb11232 |
| Short | 1669849199 | 1700    | $USD_ADDRESS         | $ETH_ADDRESS        | Call      | 0x02c293cabfbc1c82230e59561678729e6f3d6584c1d35b501f473e8c17133066 |
| Long  | 1665511435 | 1500    | $USD_ADDRESS         | $ETH_ADDRESS        | Put       | 0x000c6729d7bdcec32c210f2368a08623898cd9a6460654dbc43afd382d449fcb |
| Short | 1665511435 | 1500    | $USD_ADDRESS         | $ETH_ADDRESS        | Put       | 0x01d99bfa805d4d4c82dc39ab398453e346c54f3d47db24121d1f92af73836292 |
| Long  | 1669849199 | 1500    | $USD_ADDRESS         | $ETH_ADDRESS        | Put       | 0x06e0c3790e2b79b1e9b0287641e67c9d024a0c01239708899b8c4d523cbb7191 |
| Short | 1669849199 | 1500    | $USD_ADDRESS         | $ETH_ADDRESS        | Put       | 0x001f763c94f97f542394d27b158a855197a3244180c0829dc2782b4cdfb1f0be |
| Long  | 1669849199 | 1200    | $USD_ADDRESS         | $ETH_ADDRESS        | Put       | 0x06a7bb14708840cffd1da80edbb08662c1d3d21ce911789ed3aad02f87754e83 |
| Short | 1669849199 | 1200    | $USD_ADDRESS         | $ETH_ADDRESS        | Put       | 0x03ed8efb021436393b458ecc4f422c36c1230e482dc4957f68b539e47cd6cb71 |


# Development

## Setup

- Clone this repo with `git clone --recurse-submodules` (Protostar uses submodules)
- [Cairo quickstart](https://www.cairo-lang.org/docs/quickstart.html)
    - On a M1 Macbook, fastecdsa build might fail; [https://github.com/OpenZeppelin/nile/issues/22](this) might help.
    - note that Cairo requires Python 3.9
- [Install Protostar](https://docs.swmansion.com/protostar/docs/tutorials/installation)
- setup a virtualenv, install requirements.txt...
- `make build`; `make test`


## Alpha version deploy and test on testnet

This deploy assumes only one pool (in our case ETH/USD CALL pool) and only one option
(two tokens one for short the other for long).

First get following env vars
```
export ACCOUNT_0_ADDRESS=YOUR_ADDRESS

export ETH_ADDRESS=0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7  # goerli address
export USD_ADDRESS=0x5a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426  # goerli address
export STARKNET_WALLET=starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount

export STRIKE_PRICE=3458764513820540928000 # 1500 * 2**61
export STRIKE_PRICE_2=3919933115663279718400 # 1700 * 2**61
export STRIKE_PRICE_3=2767011611056432742400 # 1200 * 2**61
export MATURITY_1=1664992981
export MATURITY_2=1665511435
export MATURITY_3=1669849199
export OPTION_TYPE=0
export OPTION_SIDE_LONG=0
export OPTION_SIDE_SHORT=1
export INITIAL_VOLATILITY=230584300921369395200
```

Make sure that your account address, public and private keys are correctly stored as per `starknet`
library definition in `starknet_open_zeppelin_accounts.json`. Also make sure that the address
of the account in the json file corresponds to the `ACCOUNT_0_ADDRESS`.


### Deploy the AMM

Declare the AMM
```
protostar declare ./build/amm.json --network alpha-goerli
```
Export the returned hash
```
export AMM_HASH=...
```
Deploy the proxy contract
```
starknet deploy --contract ./build/proxy.json --network alpha-goerli --no_wallet --input $AMM_HASH 0 0
export MAIN_CONTRACT_ADDRESS=...
```
Specify the admin of the contract
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function initializer --input $ACCOUNT_0_ADDRESS --network alpha-goerli
```


### Deploy lptoken

Deploying lptoken and adding it to the AMM is equivalent to creating new pool!

Deploy with following arguments
```
    name = 111
    symbol = 11
    decimals = 18
    initial_supply = 0 0
    recipient = $ACCOUNT_0_ADDRESS
    owner = $MAIN_CONTRACT_ADDRESS
```

Deploy
```
protostar deploy ./build/lptoken.json  --salt 666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS --network alpha-goerli
```

Export address of the lptoken
```
export LPTOKEN_CONTRACT_ADDRESS="0x0557ec5b3d56a6abd33e5bd6da166b05cc8d90e61e52d5f5a4f22713dbcb119c"
```

### Add lptoken to the AMM

AMM address is `$MAIN_CONTRACT_ADDRESS` and address of the lptoken is `$LPTOKEN_CONTRACT_ADDRESS`.

For given lptoken the pool specific parameters have to be selected
    quote and base tokens => ETH/USD
    option type => call(0) or put(1)
```
    quote_token_address = $USD_ADDRESS
    base_token_address = $ETH_ADDRESS
    option_type = $OPTION_TYPE
    lptoken_address = $LPTOKEN_CONTRACT_ADDRESS
```
Add the lptoken
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_lptoken --inputs $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $LPTOKEN_CONTRACT_ADDRESS --network alpha-goerli
```


### Provide liquidity (ETH) to the pool

You can test that at the moment the `$ACCOUNT_0_ADDRESS` account has no lptokens.
```
starknet call --address $LPTOKEN_CONTRACT_ADDRESS --abi ./build/lptoken_abi.json --function balanceOf --inputs $ACCOUNT_0_ADDRESS --network alpha-goerli
```

To deposit liquidity first approve the pool to transact the tokens from the account to the pool. We select size of 2ETH (2 * 10**18 -> 0x1bc16d674ec80000 0 in Uint256)
```
starknet invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0x1bc16d674ec80000 0 --network alpha-goerli
```
Actually deposit the liquidity of 2ETH
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function deposit_liquidity --inputs $ETH_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE 0x1bc16d674ec80000 0 --network alpha-goerli
```


### Withdraw liquidity (ETH) from the pool

To withdraw capital use following, assume you will be will be withdrawing 1*10**18 = 0xde0b6b3a7640000 (check that the account actually has this many).
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function withdraw_liquidity --inputs $ETH_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE 0xde0b6b3a7640000 0 --network alpha-goerli
```


### Deploy option token 1 and 2

Deploy the first option token
```
protostar deploy ./build/option_token.json --network alpha-goerli --salt 666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $STRIKE_PRICE $MATURITY_1 $OPTION_SIDE_LONG
```
Export the address
```
export OPTION_TOKEN_ADDRESS_1=...
```
Deploy the second option token
```
protostar deploy ./build/option_token.json --network alpha-goerli --salt 666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $STRIKE_PRICE $MATURITY_2 $OPTION_SIDE_LONG
```
Export the address
```
export OPTION_TOKEN_ADDRESS_2=...
```

To be able to settle the options down the line and for the amm to work correctly same options have to be deployd also with opposite side (each option has to have both long and short positions).
```
protostar deploy ./build/option_token.json --network alpha-goerli --salt 666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $STRIKE_PRICE $MATURITY_1 $OPTION_SIDE_SHORT
```
Export the address
```
export OPTION_TOKEN_ADDRESS_3=...
```

Same for the second option
```
protostar deploy ./build/option_token.json --network alpha-goerli --salt 666 --inputs 111 11 18 0 0 $ACCOUNT_0_ADDRESS $MAIN_CONTRACT_ADDRESS $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $STRIKE_PRICE $MATURITY_2 $OPTION_SIDE_SHORT
```
```
export OPTION_TOKEN_ADDRESS_4=...
```


### Connect option tokens to AMM

ALL OPTIONS WITH THE SAME MATURITY HAVE TO ADDED AT ONCE, SINCE THE SAME VOLATILITY STORAGE_VAR IS USED FOR ALL OPTIONS WITH GIVEN MATURITY AT THE MOMENT.

```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs $OPTION_SIDE_LONG $MATURITY_1 $STRIKE_PRICE $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $LPTOKEN_CONTRACT_ADDRESS $OPTION_TOKEN_ADDRESS_1 $INITIAL_VOLATILITY --network alpha-goerli
```
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs $OPTION_SIDE_LONG $MATURITY_2 $STRIKE_PRICE $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $LPTOKEN_CONTRACT_ADDRESS $OPTION_TOKEN_ADDRESS_2 $INITIAL_VOLATILITY --network alpha-goerli
```
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs $OPTION_SIDE_SHORT $MATURITY_1 $STRIKE_PRICE $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $LPTOKEN_CONTRACT_ADDRESS $OPTION_TOKEN_ADDRESS_3 $INITIAL_VOLATILITY --network alpha-goerli
```
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function add_option --inputs $OPTION_SIDE_SHORT $MATURITY_2 $STRIKE_PRICE $USD_ADDRESS $ETH_ADDRESS $OPTION_TYPE $LPTOKEN_CONTRACT_ADDRESS $OPTION_TOKEN_ADDRESS_4 $INITIAL_VOLATILITY --network alpha-goerli
```


### Trade option

Trade 0x746A528800 size (measured in ETH).

First approve the sending of the capital from account to the amm.
```
starknet invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function approve --inputs $MAIN_CONTRACT_ADDRESS 0x746A528800 0 --network alpha-goerli
```
Trade the OPTION_TOKEN_ADDRESS_1 (where 0x746A528800=1152921504606 in terms of Math64x61)
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function trade_open --inputs $OPTION_TYPE $STRIKE_PRICE $MATURITY_1 $OPTION_SIDE_LONG 1152921504606 $USD_ADDRESS $ETH_ADDRESS --network alpha-goerli
```


### Close part of the option 1

"Get rid of" half of the position (size 576460752303 in terms of Math64x61)
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function trade_close --inputs $OPTION_TYPE $STRIKE_PRICE $MATURITY_1 $OPTION_SIDE_LONG 576460752303 $USD_ADDRESS $ETH_ADDRESS --network alpha-goerli
```


### Settle the position

Once a maturity has passed someone (1 entity for everyone - any entity) settles the option position from perspective of the pool.
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function expire_option_token_for_pool --inputs $LPTOKEN_CONTRACT_ADDRESS $OPTION_SIDE_SHORT $STRIKE_PRICE $MATURITY_1 --network alpha-goerli
```
and same for the other side
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function expire_option_token_for_pool --inputs $LPTOKEN_CONTRACT_ADDRESS $OPTION_SIDE_LONG $STRIKE_PRICE $MATURITY_1 --network alpha-goerli
```

After the option has been settled for pool, then users can settle their position for them selves.
```
starknet invoke --address $MAIN_CONTRACT_ADDRESS --abi ./build/amm_abi.json --function trade_settle --inputs $OPTION_TYPE $STRIKE_PRICE $MATURITY_1 $OPTION_SIDE_LONG 576460752303 $USD_ADDRESS $ETH_ADDRESS --network alpha-goerli
```


## Oracles

Currently using only Empiric oracle, which returns the median price (aggregated over multiple sources) of an asset multiplied by 10^18. Only ETH price is used for the demo at the moment. 

Website: https://empiric.network/

More oracles coming in the future (Stork, https://github.com/smartcontractkit/chainlink-starknet, etc.)


For calculating settlement price of the options we are waiting for Empiric to put historical data on-chain. At the moment we are using constant "1500" price.


## Proxy Contracts 

For proxy pattern, we decided to utilize OpenZeppelin library. Detailed explanation can be found here:

NOTE: To prevent any errors, deploy a new wallet with `starknet deploy_account --account new_account`, otherwise you might not be able to declare/deploy and use the proxy pattern. 

https://github.com/OpenZeppelin/cairo-contracts/blob/main/docs/Proxies.md

Components: 

- Implementation contract
    - Contains the logic and functions that allow the use of proxy pattern

- Proxy contract 
    - Contains function that delegates the calls to the Implementation contract

How to build:
- Implementation contract
    - Just run `protostar build` command

- Proxy contract 
    - Needs to be built separately (with `starknet-compile`, for example)
    - Navigate to proxy_contract folder
    - Run: 
    ``` 
            starknet-compile proxy.cairo    \ 
                --output ../build/proxy.json    \
                --abi ../build/proxy_abi.json   \
                --cairo_path ../lib/cairo_contracts/src 
    ```

How to deploy:

- Implementation contract
    - This contract needs to be declared only, so protostar won't be of use since it can only deploy at the moment. 
    - Navigate to build folder and run `starknet declare --contract amm.json`
    - Save 'Contract class hash', ie. `export AMM_HASH=hash`

- Proxy contract
    - This contract need to be deployed along with the Implementation contract's class hash as an input.
    - Run `starknet deploy --contract proxy.json --input $AMM_HASH`
    - Save 'Contract address', ie. `export PROXY_ADDR=address`

Use:

First thing that needs to be done is initializing the implementation contract by sending a call to the proxy contract. This will act as a Implementation contract's constructor. 

You can initialize the contract by calling the `initializer` function and passing the admin address as an input. 
```
starknet invoke \
    --address $PROXY_ADDR \
    --abi amm_abi.json \
    --function initializer \
    --input $ADMIN_ADDRESS \
    --max_fee 500000000000000

```

**Important note**: When calling any function from the implementation contract through the proxy contract, you must use the Proxy contract's adress, but the Implementations contract's abi.

Now you can verify that the admin stored inside the contract is the same as you specified.
```
starknet call \
    --address $PROXY_ADD \
    --abi amm_abi.json \ 
    --function getAdmin \
```
Also you can try to invoke some function that can only be invoked by an admin to see that you won't be able to(provided you use different account).
```
starknet invoke \
    --address $PROXY_ADD \
    --abi amm_abi.json \
    --function setAdmin --input 0x0000000000000000 \
    --account not_admin

Error message: Proxy: caller is not admin
```

But you can call/invoke any function that is not restricted, for example `init_pool`.
```
starknet invoke \
    --address $PROXY_ADDR \
    --abi amm_abi.json \
    --function init_pool \
    --max_fee 500000000000000
```

Or `get_pool_balance`.
```
starknet call \
    --address $PROXY_ADDR \
    --abi amm_abi.json \
    --function get_pool_balance \
    --input 0

0x6072000000000000000
```
etc. 

Upgrading:

Upgrading is done by invoking the `upgrade` function stored in the Implementation contract and passing the new Implementation contract's class hash as an input. While the Proxy contract doesn't store any logic, it will preserve the state when upgrading, meaning that if you invoke the `init_pool` function and then upgrade the contract, it will still return 12345 when calling the `get_pool_balance` function(provided you didn't interact with the pool). 

```
starknet invoke \
    --address $PROXY_ADDR \
    --abi amm_abi.json \
    --function upgrade \ 
    --input $NEW_AMM_HASH 
```

After upgrading, interact with the contract using the upgraded abi. 

Interacting via another contract:

This works exactly the same as with regular contracts, just use the Proxy contract's address.
```
%lang starknet

const PROXY_ADDR = $PROXY_ADDR

@contract_interface
namespace IAmm:
    func get_pool_balance(option_type : felt) -> (pool_balance : felt):
    end
end

@external
func pool_balance{syscall_ptr : felt*, range_check_ptr}(option_type : felt) -> (balance : felt):
    let (res) = IAmm.get_pool_balance(PROXY_ADDR, option_type)
    return (res)
end
```
