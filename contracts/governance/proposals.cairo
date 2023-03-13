%lang starknet

from starkware.starknet.common.syscalls import get_block_number, get_caller_address
from starkware.cairo.common.uint256 import Uint256, uint256_mul, assert_uint256_lt
from starkware.cairo.common.math import assert_nn_le, assert_not_zero, assert_le

from types import Address, PropDetails, BlockNumber, VoteStatus, ContractType
from gov_constants import PROPOSAL_VOTING_TIME_BLOCKS, GOV_TOKEN_ADDRESS, TOKEN_SHARE_REQUIRED_FOR_PROPOSAL
from openzeppelin.token.erc20.IERC20 import IERC20

@event
func Proposed(prop_id: felt, impl_hash: felt, to_upgrade: ContractType) {
}

@storage_var
func proposal_details(prop_id: felt) -> (res: PropDetails) {
}

@storage_var
func proposal_vote_ends(prop_id: felt) -> (block_number: BlockNumber) {
}

// 0 = not voted, 1 = yay, -1 = nay
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


func assert_correct_contract_type{range_check_ptr}(contract_type: ContractType) {
    assert_nn_le(contract_type, 2); // either 0, 1 or 2
    return ();
}

@external
func submit_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    impl_hash: felt, to_upgrade: ContractType
) -> (prop_id: felt) {
    // Checks

    assert_correct_contract_type(to_upgrade);
    let (caller_addr) = get_caller_address();
    
    let (caller_balance) = IERC20.balanceOf(contract_address=GOV_TOKEN_ADDRESS, account=caller_addr);
    let (total_supply) = IERC20.totalSupply(contract_address=GOV_TOKEN_ADDRESS);

    with_attr error_message("Not enough tokens to submit proposal") {
        let share = Uint256(low = TOKEN_SHARE_REQUIRED_FOR_PROPOSAL, high = 0);
        let (caller_balance_multiplied, carry) = uint256_mul(caller_balance, share);
        assert carry.low = 0;
        assert carry.high = 0;
        assert_uint256_lt(total_supply, caller_balance_multiplied);
    }

    // Write state changes to storage vars
    let (prop_id) = get_free_prop_id();
    let prop_details = PropDetails(
        impl_hash=impl_hash,
        to_upgrade=to_upgrade
    );
    proposal_details.write(prop_id, prop_details);

    let (curr_block_number) = get_block_number();
    let end_block_number = curr_block_number + PROPOSAL_VOTING_TIME_BLOCKS;
    proposal_vote_ends.write(prop_id, end_block_number);

    Proposed.emit(prop_id, impl_hash, to_upgrade);

    return (prop_id=prop_id);
}


// @notice Casts vote for the calling token holder
// @param prop_id
// @param opinion: 0 = not voted, 1 = yay, -1 = nay
@external
func vote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prop_id: felt,
    opinion: felt
) {
    // Checks
    with_attr error_message("opinion must be either 1 = yay or -1 = nay"){
        assert_not_zero(opinion);
        assert_le(opinion, 1);
        assert_le(-1, opinion);
    }

    let (caller_addr) = get_caller_address();
    let (curr_votestatus) = proposal_voted_by.read(prop_id, caller_addr);
    with_attr error_message("already voted"){
        assert curr_votestatus = 0;
    }

    let (caller_balance) = IERC20.balanceOf(contract_address=GOV_TOKEN_ADDRESS, account=caller_addr);
    with_attr error_message("governance token balance is zero or erroneous"){
        assert caller_balance.high = 0; // we store votes in felts, conversions will be done with C1.0 rewrite
        assert_not_zero(caller_balance.low);
    }

    
    let (end_block_number) = proposal_vote_ends.read(prop_id);
    let (curr_block_number) = get_block_number();
    with_attr error_message("voting already concluded"){
        assert_le(curr_block_number, end_block_number);
    }

    // Cast vote
    proposal_voted_by.write(prop_id, caller_addr, opinion);
    if(opinion == -1){
        let (curr_votes) = proposal_total_nay.read(prop_id);
        let new_votes = curr_votes + caller_balance.low;
        proposal_total_nay.write(prop_id, new_votes);
    }else{
        let (curr_votes) = proposal_total_yay.read(prop_id);
        let new_votes = curr_votes + caller_balance.low;
        proposal_total_yay.write(prop_id, new_votes);
    }
    return ();
}
