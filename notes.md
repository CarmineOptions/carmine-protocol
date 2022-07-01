# Just notes for testing the deployed demo

starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_account_balance --network alpha-goerli --inputs 123 1
starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_account_balance --network alpha-goerli --inputs 123 2
 
 --------------------------------------   
    
starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_pool_balance --network alpha-goerli --inputs 0
starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_pool_balance --network alpha-goerli --inputs 1

0x6072000000000000000    12345.0
 --------------------------------------  
    
starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_pool_option_balance --network alpha-goerli --inputs 0 2305843009213693952000 1672527600 0

starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_pool_option_balance --network alpha-goerli --inputs 0 2305843009213693952000 1672527600 1

starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_pool_option_balance --network alpha-goerli --inputs 1 2305843009213693952000 1672527600 0

starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_pool_option_balance --network alpha-goerli --inputs 1 2305843009213693952000 1672527600 1
    

 --------------------------------------  

starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_pool_volatility --network alpha-goerli --inputs 0 1644145200

starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_pool_volatility --network alpha-goerli --inputs 1 1644145200

starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_pool_volatility --network alpha-goerli --inputs 0 1672527600
	-> should be 2306028306787561975 after first trade

starknet call --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function get_pool_volatility --network alpha-goerli --inputs 1 1672527600

(option_type=option_type, maturity=maturity)

 --------------------------------------  
 
inputs: account_id, option_type, strike_price, maturity, side, option_size

This one will be rejected because of the maturity (time till maturity is negative)
starknet invoke --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function trade --network alpha-goerli --max_fee 50000000000000 --inputs 123 0 2305843009213693952000 1644145200 0 2305843009213693952

This one will go through just fine and will update all the internal metrics
starknet invoke --address $AMM_DEMO_ADDRESS --abi $ABI_PATH --function trade --network alpha-goerli --max_fee 50000000000000 --inputs 123 0 2305843009213693952000 1672527600 0 2305843009213693952