%lang starknet

// Structure containing information about last price update
// It is called 'Ticker' since we might use some other type of underlying in the future,
// like game items, which would probably require different Struct
struct TickerUpdate {
    price: Math64x61_,
    update_time: Int,
    updater_address: Address,
}

@storage_var 
func terminal_ticker(
    base_token_address: Address,
    quote_token_address: Address,
    option_maturity: Int,
) -> (last_update: TickerUpdate) {
}

// Function for retrieving terminal ticker
@external 
func get_terminal_ticker{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token_address: Address,
    quote_token_address: Address,
    maturity: Int
) -> (terminal_ticker: TickerUpdate) {
    
    let (last_ticker) = terminal_ticker.read(
        base_token_address,
        quote_token_address,
        maturity
    );
   
    return (terminal_ticker = last_ticker);
}

// Function for updating terminal ticker
@external
func update_terminal_ticker{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token_address: Address,
    quote_token_address: Address,
    maturity: Int
) {
    alloc_locals;
    
    // Get empiric key and price
    let (empiric_key) = get_empiric_key(
        quote_token_addr = quote_token_address,
        base_token_addr = base_token_address
    );
    let (empiric_price) = empiric_median_price(empiric_key);
    // TODO: Implement other oracles 
    // and some aggregation function for them

    // Assert that option hasn't expired yet, since then it would be useless
    let (current_block_time) = get_block_timestamp();
    with_attr error_message("Can't update price for option that is already expired") {
        assert_le(maturity, current_block_time - 1);
    }

    // Get callers address and create new TickerUpdate
    // TODO: Implement rewards for the last updater
    let (updater) = get_caller_address();
    let ticker_update = TickerUpdate (
        price = empiric_price,
        update_time = current_block_time,
        updater_address = updater
    );

    terminal_ticker.write(
        base_token_address,
        quote_token_address,
        maturity,
        ticker_update
    );

    return();
}
