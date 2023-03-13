%lang starknet

from starkware.starknet.common.syscalls import get_block_number, get_caller_address
from starkware.cairo.common.uint256 import Uint256, uint256_mul, assert_uint256_lt
from starkware.cairo.common.math import assert_nn_le

from types import Address, PropDetails, BlockNumber, VoteStatus, ContractType
from gov_constants import PROPOSAL_VOTING_TIME_BLOCKS, GOV_TOKEN_ADDRESS, TOKEN_SHARE_REQUIRED_FOR_PROPOSAL
from openzeppelin.token.erc20.IERC20 import IERC20

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

func assert_correct_contract_type{range_check_ptr}(contract_type: ContractType) {
    assert_nn_le(contract_type, 2); // either 0, 1 or 2
    return ();
}

@external
func submit_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    impl_hash: felt, to_upgrade: ContractType
) {
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

    return ();
}
