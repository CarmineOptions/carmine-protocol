build: contracts/core_amm/* contracts/governance/* contracts/erc20_tokens/* contracts/interfaces/* contracts/proxy_contract/*
	protostar build-cairo0

test: contracts/* tests/*.cairo build/ammcontract.cairo #testpy
	~/.protostar/dist/protostar/protostar test-cairo0 --seed 18000000 ./tests

# Takes 0 time relative to protostar, let's steer clear of this potential error src
.PHONY: build/ammcontract.cairo

build/ammcontract.cairo: tests/proxy_mock.cairo contracts/core_amm/amm.cairo contracts/core_amm/liquidity_pool.cairo contracts/core_amm/options.cairo contracts/core_amm/views_from_outside/view.cairo contracts/core_amm/state.cairo
	mkdir -p build
	cat $+ > $@
	sed -i '/%lang starknet/d' $@
	sed -i '1i %lang starknet' $@
#	sed -i '/Proxy./s/^/\/\//g' $@
