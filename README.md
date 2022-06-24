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

TBD


## Other Links

- [Twitter](https://twitter.com/CarmineOptions)
- [Web](https://carmine.finance)
- [Discord](https://discord.com/invite/uRs7j8w3bX)
- [Docs](https://carmine-finance.gitbook.io/carmine-options-amm/)

## Demo

We have build a demo.

### Deploy demo

protostar deploy build/amm.json --network alpha-goerli

### Init demo

Have an account set up including the env vars, as described [here](https://starknet.io/docs/hello_starknet/account_setup.html)

Deploy the contract
```
    protostar deploy build/amm.json --network alpha-goerli
```
From the deployment save the address
```
    export AMM_DEMO_ADDRESS='0x025aae26c014bc2f0ea8a2e7148697f4a04929ae30db65a72aaa860d746a51a5'
```

To initialize the pool run
```
    starknet invoke
    --address $AMM_DEMO_ADDRESS
    --abi build/amm_abi.json
    --function init_pool
    --network alpha-goerli
    --max_fee 41464900146837
```

To add "demo" tokens to account (some id)
```
    starknet invoke \
    --address $AMM_DEMO_ADDRESS \
    --abi build/amm_abi.json \
    --function add_fake_tokens \
    --network alpha-goerli \
    --max_fee 41464900146837 \
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

### Interact with demo

TBD
```
    starknet call \
    --address 0x025aae26c014bc2f0ea8a2e7148697f4a04929ae30db65a72aaa860d746a51a5 \
    --abi build/amm_abi.json \
    --function get_pool_balance \
    --network alpha-goerli \
    --inputs 0 1 2
```