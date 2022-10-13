%lang starknet

@contract_interface
namespace IBContract {
    func get_new_value(requested_address: felt) -> (value_update: felt) {
    }
}


@storage
func contract_balance() -> (res: Uint256) {
}

@storage_var
func last_update(request_info: Request) -> (res: Update) {
}

@storage_var
func requests(idx: felt) -> (request_info: Request) {
}

@external
func get_request(idx: felt) -> (request_info: Request) {
    let request_info = requests.read(idx);
    return request_info;
}

@external 
func update_value(request: Request) {
    alloc_locals;

    // Assert that maturity is not reached yet 
    let (current_block_time) = get_current_block_time();
    with_attr error_message("This request has already expired") {
        assert_le(maturity, current_block_time -1);
    }
    
    // Get callers address and update value    
    let (updater_address) = get_caller_address();
    let new_value = IBCContract.get_value_update(
        requested_address
    );

    // Construct new Update and write it to storage_var
    let new_update = Update (
        new_value,
        updater_address
    );

    last_update.write(
        request,
        new_update
    );
    
    return();
}

@external 
func register_request(maturity: felt, requested_address: felt, base_token_adress: felt, quote_token_address: felt, reward: Uint256) {
    alloc_locals;

    // Assert that requested maturity hasn't already expired
    let (current_block_time) = get_current_block_time();
    with_attr error_message("Can't setup Request with expired maturity") {
        assert_le(maturity, current_block_time - 1);
    }

    // Create RequestInfo
    let request = Request (
        maturity,
        requested_address,
        reward
    );

    let usable_idx = get_requests_usable_index(0);

    requests.write(
        usable_idx,
        request
    );

    move_reward_to_vault();
    
    return ();
}

@external
func pay_for_last_udpate(idx: felt) {
    alloc_locals;

    // Read Request at provided index
    let request = requests.read(idx);

    // Assert that Request has already expired
    let (current_block_time) = get_current_block_time();
    with_attr error_message("Request isn't expired yet") {
        assert_le(request.maturity, current_block_time);
    }

    // Assert that caller is the last updater
    let last_update = last_update.read(request);
    let caller_address = get_caller_address();
    with_attr error_message("Caller isn't the last updater"){
        assert caller_addres = last_update.updater_address;
    }

    // TODO: Deduct the transaction fee from reward
    pay_reward();

    // Delete request, since it has been paid
    // TODO: Make sure you can still read the last update even if the request is deleted
    remove_request(idx);

    return();
}

@view
func get_requests_usable_index{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    starting_index: felt
) -> (usable_index: felt) {
    // Returns lowest index that does not contain any specified option.

    alloc_locals;

    let (request) = requests.read(starting_index);

    let request_sum = request.maturity + request.requested_address;
    if (request_sum == 0) {
        return (usable_index = starting_index);
    }
    
    let (usable_index) = get_requests_usable_index(starting_index + 1);

    return (usable_index = usable_index);
}

func remove_request{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index: felt
) {

    let zero_request = Request (0,0,0);
    requests.write(index, zero_option);
    shift_requests(index);

    return ();
}

func shift_requests{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index: felt
) {
    alloc_locals;

    let (old_request) = requests.read(index);
    let old_request_sum = old_request.maturity + old_request.requested_address;
    assert old_request_sum = 0;

    let (next_request) = requests.read(index + 1);
    let next_request_sum = next_request.maturity + next_request.requested_address;
    if (next_request_sum == 0) {
        return();
    }

    let zero_request = Request(0, 0, 0);
    requests.write(index, next_request);
    requests.write(index + 1, zero_request);

    shift_requests(index + 1);

    return ();
}