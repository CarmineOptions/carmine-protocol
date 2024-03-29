%lang starknet

from starkware.starknet.common.syscalls import get_block_number, get_caller_address
from starkware.cairo.common.uint256 import Uint256, uint256_mul, assert_uint256_lt, uint256_lt, uint256_unsigned_div_rem
from starkware.cairo.common.math import assert_not_zero, assert_le, assert_le_felt, assert_nn, unsigned_div_rem, assert_nn_le
from starkware.cairo.common.math_cmp import is_le, is_nn

from types import Address, PropDetails, BlockNumber, VoteStatus, ContractType, VoteCounts
from gov_constants import PROPOSAL_VOTING_TIME_BLOCKS, NEW_PROPOSAL_QUORUM, QUORUM, TEAM_TOKEN_BALANCE
from gov_helpers import intToUint256

from openzeppelin.token.erc20.IERC20 import IERC20

@event
func Proposed(prop_id: felt, impl_hash: felt, to_upgrade: ContractType) {
}

@event
func Voted(prop_id: felt, voter: Address, opinion: VoteStatus) {
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

// FALSE = not applied, TRUE = applied
@storage_var
func proposal_applied(prop_id: felt) -> (res: felt) {
}

@storage_var
func proposal_initializer_run(prop_id: felt) -> (res: felt) {
}


// One investors voting power RELATIVE to other investors, not absolute.
// Absolute voting power depends on totalSupply - TEAM_TOKEN_BALANCE, see vote_investor
@storage_var
func investor_voting_power(address: felt) -> (res: felt) {
}

// Sum of all investor_voting_power
@storage_var
func total_investor_distributed_power() -> (res: felt) {
}

@view 
func get_proposal_details{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prop_id: felt
) -> (res: PropDetails) {
    let (res) = proposal_details.read(prop_id);
    return (res=res);
}

@view
func get_vote_counts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prop_id: felt
) -> (res: VoteCounts) {
    let (yay) = proposal_total_yay.read(prop_id);
    let (nay) = proposal_total_nay.read(prop_id);
    return (res=VoteCounts(yay=yay, nay=nay));
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
    with_attr error_message("wrong contract type, must be 0, 1 or 2"){
        assert_nn_le(contract_type, 2); // either 0, 1 or 2
    }
    return ();
}

func assert_voting_in_progress{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(prop_id: felt){
    let (end_block_number) = proposal_vote_ends.read(prop_id);
    with_attr error_message("voting not yet started, prop_id not found"){
        assert_not_zero(end_block_number);
    }
    let (curr_block_number) = get_block_number();
    with_attr error_message("voting already concluded"){
        // yes truly no assert_lt in Cairo 0.10.
        let block_diff = end_block_number - curr_block_number;
        assert_not_zero(block_diff);
        assert_nn(block_diff);
    }
    return ();
}

@external
func submit_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    impl_hash: felt, to_upgrade: ContractType
) -> (prop_id: felt) {
    // Checks

    // 2**237, basic impl_hash sanity check
    // this fails with one in approximately 10000 hashes, but a proposer can always do minor changes to the contract and get a new hash
    const IMPL_HASH_MIN_VALUE = 0x200000000000000000000000000000000000000000000000000000000000;
    with_attr error_message("impl_hash too small, is it really a class hash?"){
        assert_le_felt(IMPL_HASH_MIN_VALUE, impl_hash);
    }

    assert_correct_contract_type(to_upgrade);
    let (gov_token_addr) = governance_token_address.read();
    let (caller_addr) = get_caller_address();

    let (caller_balance) = IERC20.balanceOf(contract_address=gov_token_addr, account=caller_addr);
    let (total_supply) = IERC20.totalSupply(contract_address=gov_token_addr);

    with_attr error_message("Not enough tokens to submit proposal") {
        let share = Uint256(low = NEW_PROPOSAL_QUORUM, high = 0);
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
// @param opinion: 1 = yay, -1 = nay, 0 not allowed
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
    let (gov_token_addr) = governance_token_address.read();
    let (caller_addr) = get_caller_address();
    let (curr_votestatus) = proposal_voted_by.read(prop_id, caller_addr);
    with_attr error_message("already voted"){
        assert curr_votestatus = 0;
    }
    
    let (caller_balance) = IERC20.balanceOf(contract_address=gov_token_addr, account=caller_addr);
    with_attr error_message("governance token balance is zero or erroneous"){
        assert caller_balance.high = 0; // we store votes in felts, conversions will be done with C1.0 rewrite
        assert_not_zero(caller_balance.low);
    }

    
    assert_voting_in_progress(prop_id);

    // Cast vote
    proposal_voted_by.write(prop_id, caller_addr, opinion);
    if(opinion == -1){
        let (curr_votes) = proposal_total_nay.read(prop_id);
        let new_votes = curr_votes + caller_balance.low;
        assert_nn(new_votes);
        proposal_total_nay.write(prop_id, new_votes);
    }else{
        let (curr_votes) = proposal_total_yay.read(prop_id);
        let new_votes = curr_votes + caller_balance.low;
        assert_nn(new_votes);
        proposal_total_yay.write(prop_id, new_votes);
    }
    Voted.emit(prop_id, caller_addr, opinion);
    return ();
}

// @notice returns 0 if the proposal is still being voted on, 1 if it passed due to yay by >50 % of votes
// @dev assumes (doesn't check!) that voting is still in progress
func check_proposal_passed_express{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prop_id: felt
) -> (res: felt) {
    alloc_locals;
    let (gov_token_addr) = governance_token_address.read();
    let (yay_tally) = proposal_total_yay.read(prop_id);

    // Not only tokenholders are eligible, but investors as well, they hold 1/4th of the voting power
    // However, their votes are currently stored in storage_var, not tokens
    // So we must calculate 4/3 of the total supply (additional supply will be 1/4th of new total)
    // and from that 1/2, because that's 50%, So (4/3) * (1/2) = 2/3 of the total supply
    let (total_eligible_votes_from_tokenholders) = IERC20.totalSupply(contract_address=gov_token_addr);
    let TWO = Uint256(low = 2, high = 0);
    // Multiply total votes by 2
    let (intermediate, carry) = uint256_mul(total_eligible_votes_from_tokenholders, TWO);
    with_attr error_message("check_proposal_passed_express: overflow"){ 
        assert carry.low = 0;
        assert carry.high = 0;
    }
    let THREE = Uint256(low = 3, high = 0);
    // Now divide by 3
    let (minimum_for_express, _) = uint256_unsigned_div_rem(intermediate, THREE);

    let yay_tally_uint256 = intToUint256(yay_tally);
    let (cmp_res) = uint256_lt(minimum_for_express, yay_tally_uint256);
    if(cmp_res == 1){
        return (res=1);
    }
    return (res=0);
}

// @notice Returns proposal status – passed = 1, rejected = -1, voting = 0.
// rejected due to not enough votes (didn't meet quorum) = -1
// @dev fails if proposal doesn't exist
@view
func get_proposal_status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prop_id: felt
) -> (res: felt) {
    let (end_block_number) = proposal_vote_ends.read(prop_id);
    let (curr_block_number) = get_block_number();
    let block_cmp = is_le(curr_block_number, end_block_number);
    if (block_cmp == 1){
        return check_proposal_passed_express(prop_id);
    }

    let (gov_token_addr) = governance_token_address.read();
    let (nay_tally) = proposal_total_nay.read(prop_id);
    let (yay_tally) = proposal_total_yay.read(prop_id);
    let total_tally = yay_tally + nay_tally;
    let total_tally_uint256 = intToUint256(total_tally);


    with_attr error_message("unable to check quorum"){
        let share = Uint256(low = QUORUM, high = 0);
        let (tally_multiplied, carry) = uint256_mul(total_tally_uint256, share);
        assert carry.low = 0;
        assert carry.high = 0;
        // doesn't include investors, the quorum is set with that in mind
        let (total_eligible_votes) = IERC20.totalSupply(contract_address=gov_token_addr);
    }

    let (cmp_res) = uint256_lt(total_eligible_votes, tally_multiplied);
    if (cmp_res == 0) {
        return (res=-1); // didn't meet quorum
    }

    let yay_or_nay = yay_tally - nay_tally;
    if (yay_or_nay == 0){
        return (res=-1); // yay_tally = nay_tally
    }
    
    let nn = is_nn(yay_or_nay);
    if (nn == 1) {
        return (res=1); // yay_tally > nay_tally
    }else{
        return (res=-1); // yay_tally < nay_tally
    }
}


// @notice Investors don't hold tokens as of launch. They can vote only from whitelisted addresses.
// When investor votes, the real voting power of all investors is equivalent to totalSupply - TEAM_TOKEN_BALANCE.
// The real voting power is calculated in this function. Voting power of community : team : investors is 2:1:1.
@external
func vote_investor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prop_id: felt,
    opinion: felt
) {
    alloc_locals;

    // Checks
    with_attr error_message("opinion must be either 1 = yay or -1 = nay"){
        assert_not_zero(opinion);
        assert_le(opinion, 1);
        assert_le(-1, opinion);
    }

    let (caller_addr) = get_caller_address();
    let (investor_voting_power_l) = investor_voting_power.read(caller_addr);
    local investor_voting_power_local = investor_voting_power_l;
    with_attr error_message("caller not a whitelisted investor"){
        assert_not_zero(investor_voting_power_local);
    }

    let (curr_votestatus) = proposal_voted_by.read(prop_id, caller_addr);
    with_attr error_message("already voted"){
        assert curr_votestatus = 0;
    }

    assert_voting_in_progress(prop_id);

    // Calculate real voting power
    let (GOV_TOKEN_ADDRESS) = governance_token_address.read();
    let (total_supply) = IERC20.totalSupply(contract_address=GOV_TOKEN_ADDRESS);
    let total_supply_felt = total_supply.low;
    assert total_supply.high = 0;
    let real_investor_voting_power = total_supply_felt - TEAM_TOKEN_BALANCE;
    with_attr error_message("real_investor_voting power negative, check TEAM_TOKEN_BALANCE"){
        assert_nn(real_investor_voting_power);
    }

    // doesn't work because it needs non-int math
    // real_vote_power = all_investor_real_voting_power * (this_investor_invpower / total_distributed_invpower)
    // so we do
    // real_vote_power = (all_investor_real_voting_power * this_investor_invpower) / total_distributed_invpower
    // mul_div_mod or sth like this exists for uint256, but not felts AFAIK
    let (total_distributed_power) = total_investor_distributed_power.read(); // total distributed among investors
    let intermediate = real_investor_voting_power * investor_voting_power_local;
    assert_nn(intermediate);
    let (vote_power, vote_power_rem) = unsigned_div_rem(intermediate, total_distributed_power);
    with_attr error_message("vote power calculation failed"){
        assert_not_zero(vote_power);
    }

    // Cast vote
    proposal_voted_by.write(prop_id, caller_addr, opinion);
    if(opinion == -1){
        let (curr_votes) = proposal_total_nay.read(prop_id);
        let new_votes = curr_votes + vote_power;
        assert_nn(new_votes);
        proposal_total_nay.write(prop_id, new_votes);
    }else{
        let (curr_votes) = proposal_total_yay.read(prop_id);
        let new_votes = curr_votes + vote_power;
        assert_nn(new_votes);
        proposal_total_yay.write(prop_id, new_votes);
    }
    return ();
}
