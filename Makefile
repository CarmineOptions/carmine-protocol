build: contracts/*
	protostar build

test: contracts/* tests/*.cairo build/ammcontract.cairo #testpy
	~/.protostar/dist/protostar/protostar test --seed 18000000 ./tests --disable-hint-validation

testa: contracts/* tests/*.cairo build/ammcontract.cairo #testpy
	~/.protostar/dist/protostar/protostar test -x --seed 18000000 ./tests/test_get_value_of_pool_position.cairo

testb: contracts/* tests/*.cairo build/ammcontract.cairo #testpy
	~/.protostar/dist/protostar/protostar test -x --seed 18000000 ./tests/test_eco_bugs.cairo

#testpy: tests/*.py
#	pytest tests/  # TODO FIXME, is broken


# Takes 0 time relative to protostar, let's steer clear of this potential error src
.PHONY: build/ammcontract.cairo

build/ammcontract.cairo: tests/proxy_mock.cairo contracts/amm.cairo contracts/liquidity_pool.cairo contracts/options.cairo contracts/views_from_outside/view.cairo contracts/state.cairo
	mkdir -p build
	cat $+ > $@
	sed -i '/%lang starknet/d' $@
	sed -i '1i %lang starknet' $@
#	sed -i '/Proxy./s/^/\/\//g' $@
