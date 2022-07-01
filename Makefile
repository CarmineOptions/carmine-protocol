# Build and test
build: contracts/*
	protostar build
test: contracts/* tests/*
	pytest tests/
	protostar test ./tests