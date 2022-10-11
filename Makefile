# Build and test
build: contracts/*
	protostar build
test: contracts/* tests/*.cairo testpy build/ammcontract.cairo
	~/.protostar/dist/protostar/protostar test ./tests
testpy: tests/*.py
	#pytest tests/  # TODO FIXME, is broken
build/ammcontract.cairo: contracts/amm.cairo contracts/liquidity_pool.cairo
	mkdir -p build
	cat contracts/amm.cairo contracts/liquidity_pool.cairo contracts/proxy_utils.cairo contracts/terminal_price.cairo > build/ammcontract.cairo 
	sed -i '/%lang starknet/d' build/ammcontract.cairo
	sed -i '1i %lang starknet' build/ammcontract.cairo
