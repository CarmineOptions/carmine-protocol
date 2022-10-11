%lang starknet

// Structure containing information about last price update
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

@external
func update_terminal_ticker{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token_address: Address,
    quote_token_address: Address,
    maturity: Int
) {
    alloc_locals;
    
    let (empiric_key) = get_empiric_key(
        quote_token_addr = quote_token_address,
        base_token_addr = base_token_address
    );
    let (empiric_price) = empiric_median_price(empiric_key);
    // TODO: Implement other oracles 
    // and some aggregation function for them


    // Assert that option hasn't expired yet
    let (current_block_time) = get_block_timestamp();
    with_attr error_message("Can't update price for option that is already expired") {
        assert_le(maturity, current_block_time - 1);
    }

    // Get callers address and create new TickerUpdate
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

// TODO: Implement rewards for the last updater
