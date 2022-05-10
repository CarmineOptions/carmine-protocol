# Declare this file as a StarkNet contract.
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.interfaces.IERC20Votes import IERC20Votes
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_le,assert_lt, unsigned_div_rem,assert_not_equal

from openzeppelin.security.safemath import (
    uint256_checked_add,
    uint256_checked_sub_le,
    uint256_checked_sub_lt,
    uint256_checked_mul,
    uint256_checked_div_rem,
)

struct proposal_core:
    member id:felt
    member vote_start:felt
    member vote_end:felt
    member executed:felt
    member canceled:felt 
end


########################################
# Storage variables
########################################

@storage_var
func proposals_storage(i:felt)->(proposal:proposal_core):
end

@storage_var
func governance_storage() -> (governance_address : felt):
end

@storage_var
func governancee_token_address_storage()->(token_address:felt):
end

@storage_var
func quorumNumerator_storage()->(numerator:Uint256):
end

@storage_var
func quorumDenominator_storage()->(denominator:Uint256):
end

func only_governance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (caller) = get_caller_address()
    let (governance_address) = governance_storage.read()

    with_attr error_message("Only governance can perform this action"):
        assert caller = governance_address
    end
    return ()
end

func state{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proposal_id:felt)->(state:felt):
    alloc_locals
    let (proposal)=proposals_storage.read(proposal_id)
    if proposal.executed==1:
        return(1)
    else:
        if proposal.canceled==1:
            return(1)
        else:
            return(0)
        end  
    end
end


func get_votes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt)->(vote:Uint256):
    let(token_address)=governancee_token_address_storage.read()
    let(vote)=IERC20Votes.getVotes(token_address,account)
    return(vote)
end


# To create new proposal user must have at %1 of current supply
func propose_threshold{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    )->(threshold:Uint256):
    let(token_address)=governancee_token_address_storage.read()
    let(total_supply)=IERC20Votes.totalSupply(token_address)
    let (threshold,_)=uint256_checked_div_rem(total_supply,Uint256(100,0))
    return(threshold)
end



# Returns the latest quorum in terms of number of votes: `supply * numerator / denominator`.
func  quorum{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}()->(
    quorum:Uint256):

    let(token_address)=governancee_token_address_storage.read()
    let(last_pos)=IERC20Votes.getLastTotalSupplyPos(token_address)
    let(past_total_supply)=IERC20Votes.getPastTotalSupply(token_address,last_pos)

    let(numerator)=quorumNumerator_storage.read()
    let (denominator)=quorumDenominator_storage.read()

    let (total_numerator_mul)=uint256_checked_mul(past_total_supply,numerator)
    let (quorum,_)=uint256_checked_div_rem(total_numerator_mul,denominator)
    return(quorum)
end



#TODO check for call data 

@external
func  propose{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}()->(
    calldata_len: felt,calldata: felt*):
    
    let (caller)=get_caller_address()
    let (account_vote)=get_votes(caller)
    let (threshold)=propose_threshold()

    with with_attr error_message("proposer votes below threshold"):
        assert_le(threshold,account_vote)
    end


end
