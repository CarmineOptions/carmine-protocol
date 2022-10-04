# Build and test
build: contracts/*
	protostar build
test: contracts/* tests/*.cairo testpy
	mkdir -p build
	# TODO remove duplicit %lang starknet
	cat contracts/amm.cairo contracts/liquidity_pool.cairo > build/ammcontract.cairo 
	protostar test ./tests
testpy: tests/*.py
	#pytest tests/
