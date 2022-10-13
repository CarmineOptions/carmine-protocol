%lang starknet

from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_sub,
    uint256_le,
)
from starkware.starknet.common.syscalls import get_contract_address
from openzeppelin.token.erc20.IERC20 import IERC20
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.starknet.common.syscalls import get_block_timestamp, get_caller_address

// The Request struct containing information about the request
struct Request {
    maturity: felt,
    requested_address: felt,
    reward: Uint256,
}

// The Update struct containig the updated value and the updater's address
struct Update {
    value: felt,
    updater_address: felt,
}

// Contract interface for the B contracts
@contract_interface
namespace IBContract {
    func get_new_value() -> (value_update: felt) {
    }
}

// Testnet ETH Address for rewards
const ETH_ADDRESS = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

// Contains this contract's balance
@storage_var
func contract_balance() -> (res: Uint256) {
}

// Contains the latest update for given Request
@storage_var
func last_update(request_info: Request) -> (res: Update) {
}

// Contains the current requests that are not expired or cashed out
@storage_var
func requests(idx: felt) -> (request_info: Request) {
}

// Getter for this contract's balance
@view
func get_contract_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (current_balance: Uint256) {
    let (current_balance) = contract_balance.read();

    return (current_balance,);
}

// Getter for Request based on the index
// Usefull for iteration over all requests
@view
func get_request{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    idx: felt
) -> (request_info: Request) {
    let request_info = requests.read(idx);
    return request_info;
}

// Function for updating the value
// This is what the updater will be calling
@external 
func update_value{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(request: Request) {
    alloc_locals;

    // Assert that maturity is not reached yet 
    let (current_block_time) = get_block_timestamp();
    with_attr error_message("This request has already expired") {
        assert_le(request.maturity, current_block_time -1);
    }
    
    // Get new value    
    let (new_value) = IBContract.get_new_value(
        request.requested_address
    );

    // Construct new Update and write it to storage_var
    let (updater_address) = get_caller_address();
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

// Function for registering new Request
@external 
func register_request{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    maturity: felt,
    requested_address: felt,
    reward: Uint256
) {
    alloc_locals;

    // Assert that requested maturity hasn't already expired
    let (current_block_time) = get_block_timestamp();
    with_attr error_message("Can't setup Request with expired maturity") {
        assert_le(maturity, current_block_time - 1);
    }

    // Create new Request
    let request = Request (
        maturity,
        requested_address,
        reward
    );

    // Get usable index for new request and write it there
    let (usable_idx) = get_requests_usable_index(0);

    requests.write(
        usable_idx,
        request
    );

    // Move reward from the caller to contract
    let (caller_address) = get_caller_address();
    let (own_address) = get_contract_address();
    IERC20.transferFrom(
        contract_address=ETH_ADDRESS,
        sender = caller_address,
        recipient = own_address,
        amount = reward
    );

    // Update contract_balance storage_var
    let (current_balance) = contract_balance.read();
    let (new_balance, _) = uint256_add(current_balance, reward);
    contract_balance.write(new_balance);
        
    return ();
}

// Function for cashing out, used by the last updater after 
// the Request has expired
@external
func cashout_last_update{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(idx: felt) {
    alloc_locals;

    // Read Request at provided index
    let (request) = requests.read(idx);

    // Assert that Request has already expired
    let (current_block_time) = get_block_timestamp();
    with_attr error_message("Request isn't expired yet") {
        assert_le(request.maturity, current_block_time);
    }

    // Assert that caller is the last updater
    let (latest_update) = last_update.read(request);
    let (caller_address) = get_caller_address();
    with_attr error_message("Caller isn't the last updater"){
        assert caller_address = latest_update.updater_address;
    }

    // Pay the reward
    // TODO: Deduct the transaction fee from reward
    let (own_address) = get_contract_address();
    IERC20.transfer(
        contract_address = ETH_ADDRESS,
        recipient = latest_update.updater_address,
        amount = request.reward
    );

    // Update contract_balance var 
    let (current_balance) = contract_balance.read();
    let (new_balance) = uint256_sub(current_balance, request.reward);
    contract_balance.write(new_balance);
    
    // Delete request, since it has been paid
    // TODO: Make sure you can still read the last update even if the request is deleted
    remove_request(idx);

    return();
}

// Function for getting the first unused index in requests storage_var
@view
func get_requests_usable_index{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    starting_index: felt
) -> (usable_index: felt) {
    // Returns lowest index that does not contain any request
    alloc_locals;

    // Read request at provided index
    let (request) = requests.read(starting_index);

    // Make sure it is not an empty Request, since that would mean the end of
    // list is reached, in that case, return the index, since it is usable
    let request_sum = request.maturity + request.requested_address;
    if (request_sum == 0) {
        return (usable_index = starting_index);
    }
    
    // Continue to the next index until the end is reached
    let (usable_index) = get_requests_usable_index(starting_index + 1);

    return (usable_index = usable_index);
}

// Function for removing the request after it has been cashed out
func remove_request{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index: felt
) {

    // Create Request containing zeros and write it at the index in requests
    let zero_request = Request (0,0,Uint256(0, 0));
    requests.write(index, zero_request);

    // Shift remaining Requests to the left so there is not gap
    shift_requests(index);

    return ();
}

// Function for shifting requests to the left
func shift_requests{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index: felt
) {
    alloc_locals;

    // Read request at given index, assert it contains zeros
    let (old_request) = requests.read(index);
    let old_request_sum = old_request.maturity + old_request.requested_address;
    assert old_request_sum = 0;

    // Read request at the next index, if it contains zeros as well, it means we're
    // at the end of the list
    let (next_request) = requests.read(index + 1);
    let next_request_sum = next_request.maturity + next_request.requested_address;
    if (next_request_sum == 0) {
        return();
    }

    // Write next Request at current index and zero Request at next index
    let zero_request = Request(0, 0, Uint256(0, 0));
    requests.write(index, next_request);
    requests.write(index + 1, zero_request);

    // Continue to the next index
    shift_requests(index + 1);

    return ();
}