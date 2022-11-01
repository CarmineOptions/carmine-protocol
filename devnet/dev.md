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

All the necessary env variables are now stored in `_current_vars.env`, you can copy and export them in your working environment.

The current dev net can be accessed at `localhost:80`. To check that the proxy is working, you can run

```
curl localhost/liveness
```

And to check that the devnet is alive run

```
curl localhost/is_alive
```

If both services are up, you can start using local devnet.

## Devnet Commands

All `starknet` commands must be run with additional options to communicate with the local devnet:

```
starknet --chain_id 0x534e5f474f45524c49 --network_id devnet --gateway_url http://localhost --feeder_gateway_url http://localhost/ [the actual command]
```

If you have exported outputted env variables, you can use:

```
starknet --chain_id $CHAIN_ID --network_id $NETWORK_ID --gateway_url $GATEWAY --feeder_gateway_url $GATEWAY [the actual command]
```
