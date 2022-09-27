# Carmine Protocol

Carmine options protocol

Options AMM that allows any user to buy and sell options at a fair price.

For crypto funds, traders and investors who need to hedge their portfolios or trade options, this
options AMM will provide a possibility to do so. Different from competitors, this AMM allows for
selling specific options directly.


## Set up

- Clone this repo with `git clone --recurse-submodules` (Protostar uses submodules)
- [Cairo quickstart](https://www.cairo-lang.org/docs/quickstart.html)
    - On a M1 Macbook, fastecdsa build might fail; [https://github.com/OpenZeppelin/nile/issues/22](this) might help.
- [Install Protostar](https://docs.swmansion.com/protostar/docs/tutorials/installation)
- setup a virtualenv, install requirements.txt...
- `make build`; `make test`

## Current State

Just started building.


## Documentation

High level docs [here](https://carmine-finance.gitbook.io/carmine-options-amm/).
Code docs will be published soon


## Other Links

- [Twitter](https://twitter.com/CarmineOptions)
- [Web](https://carmine.finance)
- [Discord](https://discord.com/invite/uRs7j8w3bX)
- [Docs](https://carmine-finance.gitbook.io/carmine-options-amm/)

## Demo

We are building a simple demo.

### What can and can't the demo do

The demo is meant to showcase the pricing model that sits at its core. Ie it shows how the internal
metrics are updated and how the prices are created, everything else is heavily mocked.

It assumes only one currency pair is being used.

The demo is initialized with one fixed priced of the underlying asset equal to 1000.

The options are created as follows
- strike price 1000 and maturity 1644145200 (Sun Feb 06 2022 11:00:00 GMT+0000)
- strike price 1000 and maturity 1672527600 (Sat Dec 31 2022 23:00:00 GMT+0000)
- strike price 1100 and maturity 1644145200 (Sun Feb 06 2022 11:00:00 GMT+0000)
- strike price 1100 and maturity 1672527600 (Sat Dec 31 2022 23:00:00 GMT+0000)

which means that only the 1672527600 maturity can be traded in the demo (the other fails).

Most of the numbers coming in and out to/from the demo are in a Math64x61 format
(number 1.1 is send as int(1.1 * 2**61)).

### Interact with the demo

Demo is at this moment deployed here `0x01989a6d90c470d05a3259680891a0180e7c5ab8050a52f22e50ce9facf84090`
to simply use it, create env var
```
    export AMM_DEMO_ADDRESS='0x01989a6d90c470d05a3259680891a0180e7c5ab8050a52f22e50ce9facf84090'
```
and download the ABI file from the repo from `build/amm_abi.json`
```
    export ABI_PATH='build/amm_abi.json'
```

The demo was already initialized.

The example assumes that user's starknet account is existing and some tokens on it to pay for fees
```
export STARKNET_NETWORK=alpha-goerli
export STARKNET_WALLET=starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount
```

#### Add tokens to the pools
First possible interaction is to add fake tokens to the pool
```
    starknet invoke \
    --address $AMM_DEMO_ADDRESS \
    --abi $ABI_PATH \
    --function add_fake_tokens \
    --network alpha-goerli \
    --max_fee 50000000000000 \
    --inputs 123 230584300921369395200 461168601842738790400
```
the `--inputs 123 230584300921369395200 461168601842738790400` says add 230584300921369395200
(100 * 2 ** 61) TOKEN_1 tokens into the CALL pool and 461168601842738790400 (200 * 2 ** 61) TOKEN_2
into the PUT pool, both for account 123. The tokens used are fake and virtual tokens.

To validate that the tokens were added, and to see how many were added in total
(run before and after the addition to see the difference)
```
    starknet call \
    --address $AMM_DEMO_ADDRESS \
    --abi $ABI_PATH \
    --function get_account_balance \
    --network alpha-goerli \
    --inputs 123 1
```
where `--inputs 123 1` for TOKEN_1 (call pool) and `--inputs 123 2` for TOKEN_2 (put pool).

To validate that the tokens were added into the CALL and PUT pools validate the size of the pool
before and after the addition.
```
    starknet call \
    --address $AMM_DEMO_ADDRESS \
    --abi $ABI_PATH \
    --function get_pool_balance \
    --network alpha-goerli \
    --inputs 0
```
`--inputs 0` for call pool and `--inputs 1` and put option.

#### Get price of an option

TBD

#### Trade option

Trading an option means that a note of the trade is made, the size of the pool gets updated
and volatility gets updated.
```
    starknet invoke \
    --address $AMM_DEMO_ADDRESS \
    --abi $ABI_PATH \
    --function trade \
    --network alpha-goerli \
    --max_fee 50000000000000 \
    --inputs 123 0 2305843009213693952000 1672527600 0 1
```
the `--inputs` correspond to the following
`account_id, option_type, strike_price, maturity, side, option_size`

You can check the call pool_balance with one of the above mentioned calls. The account_balance
does not change (since it measures only the staked capital). You can also check
the available_options with
```
    starknet call \
    --address $AMM_DEMO_ADDRESS \
    --abi $ABI_PATH \
    --function get_pool_option_balance \
    --network alpha-goerli \
    --max_fee 50000000000000 \
    --inputs 0 2305843009213693952000 1672527600 1
```
where `--inputs` contains `option_type, strike_price, maturity, side`.



### Deploy demo

Assumes the following to be set in .env: `STARKNET_NETWORK=alpha-goerli`, `PROTOSTAR_ACCOUNT_PRIVATE_KEY`, `PROTOSTAR_ACCOUNT_ADDRESS`

```
    protostar build
    protostar deploy ./build/amm.json --network testnet
```

Save the contract address printed by the last command like this:

(Note how initial_supply is two zeros since it's uint256)

(Unclear how to pass strings)

```
    export MAIN_CONTRACT_ADDRESS="0x040fa3b63f3c844c67c6e47c9fa4c289f41f86e36e5aaead81299a6915b90858"
    protostar deploy build/lptoken.json --network testnet --salt 666 --inputs 111 11 18 0 0 0 $MAIN_CONTRACT_ADDRESS
```

Write down or save the contract address.

```
    export LPTOKEN_ONE_CONTRACT_ADDRESS="0x037fd36a3b34cc0405bf7662f15ce91bd598b5f47c2e356755527379b385d51a"
    # Run starknet invoke on add_lptoken. (Untested because of dependency hell:/
```

Now it should be possible to poke around the contract.


### Init demo

Have an account set up including the env vars, as described [here](https://starknet.io/docs/hello_starknet/account_setup.html)

Deploy the contract
```
    protostar deploy build/amm.json --network alpha-goerli
```
From the deployment save the address
```
    export AMM_DEMO_ADDRESS='0x01989a6d90c470d05a3259680891a0180e7c5ab8050a52f22e50ce9facf84090'
```
and use the ABI file `build/amm_abi.json`
```
    export ABI_PATH='build/amm_abi.json'
```

To initialize the pool run
```
    starknet invoke \
    --address $AMM_DEMO_ADDRESS \
    --abi $ABI_PATH \
    --function init_pool \
    --network alpha-goerli \
    --max_fee 50000000000000
```

To add "demo" tokens to account (some id)
```
    starknet invoke \
    --address $AMM_DEMO_ADDRESS \
    --abi build/amm_abi.json \
    --function add_fake_tokens \
    --network alpha-goerli \
    --max_fee 50000000000000 \
    --inputs 123 100000 100000
```

To validate that tokens were added
```
    starknet call \
    --address 0x025aae26c014bc2f0ea8a2e7148697f4a04929ae30db65a72aaa860d746a51a5 \
    --abi build/amm_abi.json \
    --function get_account_balance \
    --network alpha-goerli \
    --inputs 123 1
```

### Oracles

Currently using only Empiric oracle, which returns the median price(aggregated over multiple sources) of an asset multiplied by 10^18. Only ETH price is used for the demo at the moment. 

Website: https://empiric.network/

More oracles coming in the future (Stork, https://github.com/smartcontractkit/chainlink-starknet, etc.)
