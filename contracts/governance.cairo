# Declare this file as a StarkNet contract.
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from contracts.interfaces.IERC20Votes import IERC20Votes
from starkware.cairo.common.uint256 import (Uint256,uint256_le,uint256_lt,uint256_eq)
from starkware.cairo.common.math import assert_le, assert_lt, unsigned_div_rem, assert_not_equal,assert_not_zero
from starkware.cairo.common.math_cmp import is_le, is_le_felt
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_keccak.keccak import (keccak_felts,finalize_keccak)
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from starkware.starknet.common.syscalls import call_contract,get_contract_address, get_caller_address, get_tx_info
from contracts.library.array_manipulation import get_new_array, copy_from_to, join
from contracts.array_utils import (
    assert_index_in_array_length,
    assert_check_array_not_empty,
    assert_from_smaller_then_to,
)

from openzeppelin.security.safemath import (
    uint256_checked_add,
    uint256_checked_sub_le,
    uint256_checked_sub_lt,
    uint256_checked_mul,
    uint256_checked_div_rem,
)

const TRUE = 1
const FALSE = 0

#
struct proposal_core:
    member vote_start : felt
    member vote_end : felt
    member executed : felt
    member canceled : felt
end

struct Call:
    member to: felt
    member selector: felt
    member calldata_len: felt
    member calldata: felt*
end
########################################
# events
########################################

# Event emitted whenever proposal created
@event
func new_proposal_created(proposal_id : Uint256, vote_start : felt, vote_end : felt):
end

# Event emitted whenver proposal with sufficient number of votes executed
@event
func proposal_executed(proposal_id : Uint256, vote_start : felt, vote_end : felt):
end
########################################
# Storage variables
########################################


#  Total proposals created
@storage_var
func proposals_storage(id : Uint256) -> (proposal : proposal_core):
end

@storage_var
func proposal_vote_count_storage(id : Uint256)->(total_vote_weight:Uint256):
end

@storage_var
func proposal_account_votes(account : felt)->(vote:Uint256):
end

# Governance adress 
@storage_var
func governance_storage() -> (governance_address : felt):
end

# Governance token for calculating users voting power
@storage_var
func governance_token_address_storage() -> (token_address : felt):
end

# Numerator for calculating qurom threshold
@storage_var
func quorum_numerator_storage() -> (numerator : Uint256):
end

# Denominator for calculating qurom threshold
@storage_var
func quorum_denominator_storage() -> (denominator : Uint256):
end



@constructor
func constructor {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _governance_adress:felt, _token:felt
):
    with_attr error_message("GOvernance:: invalid initial parameters"):
        assert_not_zero(_governance_adress)
        assert_not_zero(_token)
    end
    governance_storage.write(_governance_adress)
    governance_token_address_storage.write(_token)
    return()
end

########################################
# View fucntions
########################################


# Last state of given proposal
@view
func state{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proposal_id : Uint256
) -> (state : felt):
    alloc_locals
    let (proposal) = proposals_storage.read(proposal_id)
    let (current_block)=get_block_number()
    if proposal.executed == 1:
        # executed state=0
        return (0)
    else:
        # canceled state=1
        if proposal.canceled == 1:
            return (1)
        else:
            let (proposal)=proposals_storage.read(proposal_id)

            with_attr error_message("Governor: unknown proposal id"):
                assert_not_equal(0,proposal.vote_start)
            end
            let (is_vote_start_bigger_than_current_block)=is_le(current_block,proposal.vote_start)
            if is_vote_start_bigger_than_current_block==1:
                # pending state
                return(3)
            else:
                let (is_vote_end_bigger_than_current_block)=is_le(current_block,proposal.vote_end)
                if is_vote_end_bigger_than_current_block==1:
                    # active state
                    return(4)
                else:
                    let (is_qurom_reached)=quorum_reached(proposal_id)
                    
                    # TODO add no state for votes
                    #let (is_vote_succeeded)=_vote_succeeded(proposal_id)
                    let is_proposal_succeeded=is_qurom_reached
                    if is_proposal_succeeded==TRUE:
                        #success state
                        return(5)
                    else:
                        #fail state
                        return(6)
                    end    
                end
            end
        end
    end
end

# Account's  voting power for given block
@view
func get_votes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt,block_number:felt
) -> (vote : Uint256):
    let (token_address) = governance_token_address_storage.read()
    let (vote) = IERC20Votes.getPastVotes(token_address, account,block_number)
    return (vote)
end


# Returns the latest quorum in terms of number of votes: `supply * numerator / denominator`.
@view
func quorum{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    quorum : Uint256
):
    alloc_locals
    let (token_address) = governance_token_address_storage.read()
    let (last_pos) = IERC20Votes.getLastTotalSupplyPos(token_address)
    let (past_total_supply) = IERC20Votes.getPastTotalSupply(token_address, last_pos)

    let (local numerator) = quorum_numerator_storage.read()
    let (local denominator) = quorum_denominator_storage.read()

    let (total_numerator_mul) = uint256_checked_mul(past_total_supply, numerator)
    let (quorum, _) = uint256_checked_div_rem(total_numerator_mul, denominator)
    return (quorum)
end

@view
func quorum_reached {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proposal_id:Uint256)->(result:felt): 
    alloc_locals
    let (local total_vote)=proposal_vote_count_storage.read(proposal_id)
    let (quorum_limit)=quorum()
    let (is_total_vote_bigger_than_quorum_limit)=uint256_le(quorum_limit,total_vote)
    if is_total_vote_bigger_than_quorum_limit==1:
        return(TRUE)
    else:
        return(FALSE)
    end
end

# Proposal create block (vote start)
@view
func proposal_snapshot{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proposal_id : Uint256
) -> (vote_start : felt):
    let (proposal : proposal_core) = proposals_storage.read(proposal_id)
    return (proposal.vote_start)
end


# Proposal end block (vote end)
@view
func proposal_deadline{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proposal_id : Uint256
) -> (vote_end : felt):
    let (proposal : proposal_core) = proposals_storage.read(proposal_id)
    return (proposal.vote_end)
end



########################################
# External fucntions
########################################

# TODO check for call data

# Create new proposal
@external
func propose{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    targets_len : felt,
    targets : felt*,
    values_len : felt,
    values : felt*,
    calldata_len : felt,
    calldata : felt*,
    data_offset_len : felt,
    data_offset : felt*,
):  
    alloc_locals
    let (caller) = get_caller_address()
    let (current_block)=get_block_number()
    let (local account_vote) = get_votes(caller,current_block-1)
    let (threshold) = _propose_threshold()

    let (threshold_condition)=uint256_lt(threshold, account_vote)

    with_attr error_message("proposer votes below threshold"):
        assert threshold_condition=1
    end
    with_attr error_message("invalid proposal lenght"):
        assert targets_len = values_len
        assert targets_len = calldata_len
        assert_lt(0, targets_len)
    end


    let (proposal_id) = _hash_proposal(
        targets_len, targets, values_len, values, calldata_len, calldata,data_offset_len ,data_offset ,
    )

    let (proposal_from_Storage) = proposals_storage.read(proposal_id)
    with_attr error_message("invalid proposal lenght"):
        assert proposal_from_Storage.vote_start = 0
    end
    let proposal = proposal_core(current_block, current_block + 1000, 0, 0)
    proposals_storage.write(proposal_id, proposal)
    new_proposal_created.emit(proposal_id, current_block, current_block + 1000)
    return()
end



@external
func cast_vote {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proposal_id:Uint256, support:felt
):  
    let (caller)=get_caller_address()
    _cast_vote(proposal_id,caller,support)
    return()
end


# TODO not completed
# Execute a proposal with  sufficient number of votes
@external
func execute {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    targets_len : felt,
    targets : felt*,
    values_len : felt,
    values : felt*,
    calldata_len : felt,
    calldata : felt*,
    data_offset_len:felt,
    data_offset:felt*
)->(result:felt):  
    alloc_locals
    let (local proposal_id) = _hash_proposal(
            targets_len, targets, values_len, values, calldata_len, calldata,data_offset_len ,data_offset ,
        )
    let (proposal_state)= state(proposal_id)

    with_attr error_message("Governance:: Proposal not succeeded"):
        assert proposal_state=5
    end
    _execute(    
        targets_len ,
        targets,
        values_len ,
        values ,
        calldata_len,
        calldata,data_offset_len,
    data_offset)

    return(TRUE)

end

########################################
# Internal functions
########################################

# Governance modifier checks only contracts can call 
func _only_governance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (caller) = get_caller_address()
    let (governance_address) = governance_storage.read()

    with_attr error_message("Only governance can perform this action"):
        assert caller = governance_address
    end
    return ()
end

# Threshold value for creating new proposal
# To create new proposal user must have at %1 of current supply
func _propose_threshold{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    threshold : Uint256
):
    let (token_address) = governance_token_address_storage.read()
    let (total_supply) = IERC20Votes.totalSupply(token_address)
    let (threshold, _) = uint256_checked_div_rem(total_supply, Uint256(100, 0))
    return (threshold)
end


# Unique hash value for given proposal paramaters
func _hash_proposal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    targets_len : felt,
    targets : felt*,
    values_len : felt,
    values : felt*,
    calldata_len : felt,
    calldata : felt*,
    data_offset_len : felt,
    data_offset : felt*,
) -> (hashed_result : Uint256):
    alloc_locals

    let (target_values_join_len, target_values_join) = join(
        targets_len, targets, values_len, values
    )
    let (target_values_calldata_join_len, target_values_calldata_join) = join(
        target_values_join_len, target_values_join, calldata_len, calldata
    )

    let (result_array_len, result_array) = join(
        target_values_calldata_join_len, target_values_calldata_join, data_offset_len, data_offset
    )

    let (local bitwise_ptr : BitwiseBuiltin*) = alloc()
    let (local keccak_ptr_start) = alloc()
    let keccak_ptr = keccak_ptr_start

    let (hashed_result:Uint256) = keccak_felts{bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr}(result_array_len, result_array)
    # TODO  control finalize keccak
    #finalize_keccak(keccak_ptr_start=keccak_ptr_start)
    return (hashed_result)
end


func _cast_vote {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proposal_id:Uint256,voter:felt, support:felt
)->(result:felt):  
    alloc_locals
    let(local proposal:proposal_core)=proposals_storage.read(proposal_id)
    let (proposal_state)=state(proposal_id)

    with_attr error_message("Governance: proposal not active"):
        assert proposal_state=4
    end

    let (account_vote)=proposal_account_votes.read(voter)
    let(is_account_voting_once) =uint256_eq(account_vote,Uint256(0,0))
    
    with_attr error_message("Governance:: account already voted"):
        assert is_account_voting_once=1
    end

    let (voter_weight)= get_votes(voter, proposal.vote_start)
    let(total_weight_before)=proposal_vote_count_storage.read(proposal_id)
    proposal_account_votes.write(voter,voter_weight)
    let(new_total)=uint256_checked_add(total_weight_before,voter_weight)
    proposal_vote_count_storage.write(proposal_id,new_total)
    return(TRUE)
end

func _execute {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    targets_len : felt,
    targets : felt*,
    values_len : felt,
    values : felt*,
    calldata_len : felt,
    calldata : felt*,
    data_offset_len : felt,
    data_offset : felt*,
)->(response_len:felt,response:felt*):

    alloc_locals
    let (__fp__, _) = get_fp_and_pc()
    let (calls : Call*) = alloc()
    _from_array_to_call(targets_len,targets, values, calldata, data_offset ,calls)
    let calls_len = targets_len
    

    let (response : felt*) = alloc()
    let (response_len) = _execute_list(calls_len, calls, response)
    return (response_len=response_len, response=response)

end


func _execute_list{syscall_ptr: felt*}(
        calls_len: felt,
        calls: Call*,
        response: felt*
    ) -> (response_len: felt):
    alloc_locals

    # if no more calls
    if calls_len == 0:
        return (0)
    end

    # do the current call
    let this_call: Call = [calls]
    let res = call_contract(
        contract_address=this_call.to,
        function_selector=this_call.selector,
        calldata_size=this_call.calldata_len,
        calldata=this_call.calldata
    )
    # copy the result in response
    memcpy(response, res.retdata, res.retdata_size)
    # do the next calls recursively
    let (response_len) = _execute_list(calls_len - 1, calls + Call.SIZE, response + res.retdata_size)
    return (response_len + res.retdata_size)
end

func _from_array_to_call{syscall_ptr: felt*}(
        targets_len: felt,
        targets: felt*,
        values:felt*,
        calldata: felt*,
        data_offset:felt*,
        calls: Call*
    ):
    # if no more calls
    if targets_len == 0:
        return ()
    end

    # parse the current call
    assert [calls] = Call(
            to=[targets],
            selector=[values],
            calldata_len=[data_offset]-[data_offset-1],
            calldata=calldata + [data_offset]
        )
    # parse the remaining calls recursively
    _from_array_to_call(targets_len - 1, targets +1, values+1,calldata,data_offset+1, calls + Call.SIZE)
    return ()
end