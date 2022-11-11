build: contracts/*
	protostar build

test: contracts/* tests/*.cairo build/ammcontract.cairo #testpy
	~/.protostar/dist/protostar/protostar test -x ./tests/

#testpy: tests/*.py
#	pytest tests/  # TODO FIXME, is broken


# Takes 0 time relative to protostar, let's steer clear of this potential error src
.PHONY: build/ammcontract.cairo

build/ammcontract.cairo: contracts/amm.cairo contracts/liquidity_pool.cairo contracts/options.cairo contracts/view.cairo contracts/state.cairo tests/proxy_mock.cairo
	mkdir -p build
	cat tests/proxy_mock.cairo contracts/amm.cairo contracts/liquidity_pool.cairo contracts/options.cairo contracts/view.cairo contracts/state.cairo > $@
	sed -i '/%lang starknet/d' $@
	sed -i '1i %lang starknet' $@
#	sed -i '/Proxy./s/^/\/\//g' $@
