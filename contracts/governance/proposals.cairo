%lang starknet

from types import Address, PropDetails, BlockNumber, VoteStatus, ContractType

@storage_var
func proposal_details(prop_id: felt) -> (res: PropDetails) {
}

@storage_var
func proposal_vote_ends(prop_id: felt) -> (block_number: BlockNumber) {
}

@storage_var
func proposal_voted_by(prop_id: felt, token_holder: Address) -> (res: VoteStatus) {
}

@storage_var
func proposal_total_yay(prop_id: felt) -> (res: felt) {
}

@storage_var
func proposal_total_nay(prop_id: felt) -> (res: felt) {
}

func get_free_prop_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (freeid: felt) {
    return _get_free_prop_id(0);
}

func _get_free_prop_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    currid: felt
) -> (freeid: felt) {
    let (res) = proposal_vote_ends.read(currid); // shorter values than _details
    if (res == 0) {
        return (freeid = currid);
    }else{
        return _get_free_prop_id(currid + 1);
    }
}

@external
func submit_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    impl_hash: felt, to_upgrade: ContractType
) {
    return ();
}
