# Run Devnet Locally

To run devnet locally, first make sure that you have built the version that you want to test. If not, run first

```
make build
```

Built contract is passed into the devnet via Docker volumes.

To start devnet run in the project root:

```
docker compose up
```

Wait until the deploy is done, it will let you know via terminal output.

All the necessary env variables are now stored in `/devnet/deployed_vars.env`, you can copy and export them in your working environment.

The current dev net can be accessed at `localhost:5050`. To check that the proxy is working, you can run

```
curl localhost/liveness
```

And to check that the devnet is alive run

```
curl localhost/is_alive
```

If both services are up, you can start using local devnet.

## Devnet Commands

Make sure that local variable from `/devnet/deployed_vars.env` are exported inside your working environment. Variables starting with `STARKNET_...` tell the starknet to use your running devnet.

To send funds to your FE wallet run this command:

```
starknet invoke --address $ETH_ADDRESS --abi ./build/lptoken_abi.json --function transfer --inputs [wallet address] 99999999999999999999 0
```
