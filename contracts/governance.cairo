# Declare this file as a StarkNet contract.
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.interfaces.IERC20Votes import IERC20Votes
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import assert_le, assert_lt, unsigned_div_rem, assert_not_equal
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.keccak import keccak_felts
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

@event
func new_proposal_created(proposal_id : felt, vote_start : felt, vote_end : felt):
end

########################################
# Storage variables
########################################


#  
@storage_var
func proposals_storage(id : Uint256) -> (proposal : proposal_core):
end


# Governance adress 
@storage_var
func governance_storage() -> (governance_address : felt):
end

# Governance token for calculating users voting power
@storage_var
func governancee_token_address_storage() -> (token_address : felt):
end

# numerator for calculating qurom threshold
@storage_var
func quorum_numerator_storage() -> (numerator : Uint256):
end

# denominator for calculating qurom threshold
@storage_var
func quorumDenominator_storage() -> (denominator : Uint256):
end

# GOvernance modifier checks only contracts can call 
func only_governance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (caller) = get_caller_address()
    let (governance_address) = governance_storage.read()

    with_attr error_message("Only governance can perform this action"):
        assert caller = governance_address
    end
    return ()
end

func state{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proposal_id : felt
) -> (state : felt):
    alloc_locals
    let (proposal) = proposals_storage.read(proposal_id)
    if proposal.executed == 1:
        return (1)
    else:
        if proposal.canceled == 1:
            return (1)
        else:
            return (0)
        end
    end
end

# get account's latest voting power
func get_votes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (vote : Uint256):
    let (token_address) = governancee_token_address_storage.read()
    let (vote) = IERC20Votes.getVotes(token_address, account)
    return (vote)
end

# To create new proposal user must have at %1 of current supply
func propose_threshold{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    threshold : Uint256
):
    let (token_address) = governancee_token_address_storage.read()
    let (total_supply) = IERC20Votes.totalSupply(token_address)
    let (threshold, _) = uint256_checked_div_rem(total_supply, Uint256(100, 0))
    return (threshold)
end

# Returns the latest quorum in terms of number of votes: `supply * numerator / denominator`.
func quorum{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    quorum : Uint256
):
    let (token_address) = governancee_token_address_storage.read()
    let (last_pos) = IERC20Votes.getLastTotalSupplyPos(token_address)
    let (past_total_supply) = IERC20Votes.getPastTotalSupply(token_address, last_pos)

    let (numerator) = quorum_numerator_storage.read()
    let (denominator) = quorumDenominator_storage.read()

    let (total_numerator_mul) = uint256_checked_mul(past_total_supply, numerator)
    let (quorum, _) = uint256_checked_div_rem(total_numerator_mul, denominator)
    return (quorum)
end


func proposal_snapshot{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proposal_id : felt
) -> (vote_start : felt):
    let (proposal : proposal_core) = proposals_storage.read(proposal_id)
    return (proposal.vote_start)
end

func proposal_deadline{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proposal_id : felt
) -> (vote_end : felt):
    let (proposal : proposal_core) = proposals_storage.read(proposal_id)
    return (proposal.vote_end)
end

# TODO check for call data

@external
func propose{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    targets_len : felt,
    targets : felt*,
    values_len : felt,
    values : felt*,
    calldata_len : felt,
    calldata : felt*,
):
    let (caller) = get_caller_address()
    let (account_vote) = get_votes(caller)
    let (threshold) = propose_threshold()

    with_attr error_message("proposer votes below threshold"):
        assert_le(threshold, account_vote)
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

    let (proposal_id) = hash_proposal(
        targets_len, targets, values_len, values, calldata_len, calldata
    )

    let (proposal_from_Storage) = proposals_storage.read(proposal_id)
    with_attr error_message("invalid proposal lenght"):
        assert proposal.vote_start = 0
    end

    let (block_number) = get_block_number()

    let (proposal : proposal_core) = proposal_core(block_number, block_number + 1000, 0, 0)
    proposals_storage.write(proposal_id, proposal)
    new_proposal_created.emit(proposal_id, block_number, block_number + 1000)
end

func hash_proposal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
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

    let (hashed_result) = keccak_felts(result_array_len, result_array)
    return (hashed_result)
end
