# Carmine Protocol

This repository contains the smart contracts for the Carmine Protocol, developed by Carmine Finance s.r.o.

The Protocol lets any user to buy and sell options at a fair price.

## Current State

We are live on ✨[mainnet](https://app.carmine.finance)✨!

## Documentation

High level docs [here](https://carmine-finance.gitbook.io/carmine-options-amm/).
Code docs will be published soon, but the code is pretty well commented.

## Other Links

- [Twitter](https://twitter.com/CarmineOptions)
- [Web](https://carmine.finance)
- [Discord](https://discord.com/invite/uRs7j8w3bX)
- [Docs](https://carmine-finance.gitbook.io/carmine-options-amm/)


## Oracles

Currently using only [Pragma](https://www.pragmaoracle.com/) (formerly Empiric) oracle. When the AMM detects that Pragma is not publishing up-to-date data for any reason, trading is automatically halted.

We're working on our own solution to make arbitrary aggregated timestamped data available on the blockchain, the [Chronos oracle](https://github.com/CarmineOptions/Chronos-Oracle). This will be used in the future in addition to traditional oracles to mitigate spot price manipulation around expiry and ensure the latest possible price is used when settling options.

# Development

## Setup on GitHub Codespaces

The easiest way to get up and running is to use Github Codespaces or VSCode with Docker and Devcontainers.

## Local setup

- Clone this repo with `git clone --recurse-submodules` (Protostar uses submodules)
- [Cairo quickstart](https://www.cairo-lang.org/docs/quickstart.html)
    - On a M1 Macbook, fastecdsa build might fail; [this](https://github.com/OpenZeppelin/nile/issues/22) might help.
    - note that Cairo requires Python 3.9
- [Install Protostar](https://docs.swmansion.com/protostar/docs/tutorials/installation)
- setup a virtualenv, install requirements.txt...
- `make build`; `make test`
- nice to have: `echo $'\a'` plays a beep so you know to get back to work


## Deployment

See `scripts/deploy_governance.py`, this scripts declares all contracts and then deploys the governance contract, which, during its initialization deploys everything else through Starknet deploy syscalls. 


## Proxy Contracts 

For proxy pattern, we decided to utilize OpenZeppelin library. Detailed explanation can be found [here](https://github.com/OpenZeppelin/cairo-contracts/blob/main/docs/Proxies.md).

NOTE: To prevent any errors, deploy a new wallet with `starknet deploy_account --account new_account`, otherwise you might not be able to declare/deploy and use the proxy pattern. 

Components: 

- Implementation contract
    - Contains the logic and functions that allow the use of proxy pattern

- Proxy contract 
    - Contains function that delegates the calls to the Implementation contract

How to build:
 - Run `protostar build` command

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


## License

Everything in this repository is licensed under the MIT license, see [`LICENSE`](./LICENSE).  

(c) Carmine Finance s.r.o. 2023
