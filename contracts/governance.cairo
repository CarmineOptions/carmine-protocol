# Declare this file as a StarkNet contract.
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from contracts.interfaces.IERC20Votes import IERC20Votes
from starkware.cairo.common.uint256 import (Uint256,uint256_le,uint256_lt)
from starkware.cairo.common.math import assert_le, assert_lt, unsigned_div_rem, assert_not_equal
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_keccak.keccak import (keccak_felts,finalize_keccak)
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
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


#
struct proposal_core:
    member vote_start : felt
    member vote_end : felt
    member executed : felt
    member canceled : felt
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

@storage
func proposal_vote_count_storage(id : Uint256)->(total_vote_weight:Uint256):
end

# Governance adress 
@storage_var
func governance_storage() -> (governance_address : felt):
end

# Governance token for calculating users voting power
@storage_var
func governancee_token_address_storage() -> (token_address : felt):
end

# Numerator for calculating qurom threshold
@storage_var
func quorum_numerator_storage() -> (numerator : Uint256):
end

# Denominator for calculating qurom threshold
@storage_var
func quorum_denominator_storage() -> (denominator : Uint256):
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
    if proposal.executed == 1:
        # executed state=0
        return (0)
    else:
        # canceled state=1
        if proposal.canceled == 1:
            return (1)
        else:
            # proposal active
            return (3)
        end
    end
end

# Account's  voting power for given block
@view
func get_votes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt,block_number:felt
) -> (vote : Uint256):
    let (token_address) = governancee_token_address_storage.read()
    let (vote) = IERC20Votes.getPastVotes(token_address, account,block_number)
    return (vote)
end


# Returns the latest quorum in terms of number of votes: `supply * numerator / denominator`.
@view
func quorum{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    quorum : Uint256
):
    alloc_locals
    let (token_address) = governancee_token_address_storage.read()
    let (last_pos) = IERC20Votes.getLastTotalSupplyPos(token_address)
    let (past_total_supply) = IERC20Votes.getPastTotalSupply(token_address, last_pos)

    let (local numerator) = quorum_numerator_storage.read()
    let (local denominator) = quorum_denominator_storage.read()

    let (total_numerator_mul) = uint256_checked_mul(past_total_supply, numerator)
    let (quorum, _) = uint256_checked_div_rem(total_numerator_mul, denominator)
    return (quorum)
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
# End fucntions
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
    end

    with_attr error_message("invalid proposal lenght"):
        assert targets_len = calldata_len
    end

    with_attr error_message("invalid proposal lenght"):
        assert_lt(0, targets_len)
    end

    let (proposal_id) = _hash_proposal(
        targets_len, targets, values_len, values, calldata_len, calldata
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
    _casty_vote(proposal_id,caller,support)
end


# Executed a proposal with  sufficient number of votes
@external
func execute {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
):  



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
    let (token_address) = governancee_token_address_storage.read()
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
) -> (hashed_result : Uint256):
    alloc_locals

    let (target_values_join_len, target_values_join) = join(
        targets_len, targets, values_len, values
    )
    let (result_array_len, result_array) = join(
        target_values_join_len, target_values_join, calldata_len, calldata
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
):  
    let(proposal:proposal_core)=proposals_storage.read(proposal_id)
    let (proposal_state)=state(proposal_id)

    with_attr error_message("Governance: proposal not active"):
        assert proposal_state=3
    end

    let (voter_weight)= get_votes(voter, proposal.vote_start)

    let(total_weight_before)=proposal_vote_count_storage.read(proposal_id)
    let(new_total)=uint256_checked_add(total_weight_before,voter_weight)
    let(total_weight_after)=proposal_vote_count_storage.write(proposal_id,new_total)

end