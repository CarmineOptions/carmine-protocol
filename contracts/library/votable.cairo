%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_sub,
    uint256_mul,
    uint256_le,
    uint256_lt,
    uint256_check,
    uint256_eq,
    uint256_neg,
    uint256_signed_nn,
    uint256_unsigned_div_rem,
)

from library.safemath import (
    uint256_checked_add,
    uint256_checked_sub_le,
    uint256_checked_sub_lt,
    uint256_checked_mul,
    uint256_checked_div_rem,
)
from starkware.cairo.common.math_cmp import is_le,is_not_zero
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero, assert_lt

#
# Storage
#
struct Votable_checkpoint:
    member blockNumber:felt
    member votes:Uint256
end

# Checkpoints for every accounts
@storage_var
func Votable_checkpoint_storage(account:felt,i:felt)->(checkpoint:Votable_checkpoint):
end

# Checkpoints lenght for every accounts
@storage_var
func Votable_checkpoints_lenght_storage(account:felt)->(lenght:felt):
end


# Total supply checkpoints
@storage_var
func Votable_total_supply_checkpoint_storage(i:felt)->(checkpoint:Votable_checkpoint):
end

# Total supply checkpoints lenght
@storage_var
func Votable_total_supply_lenght_storage()->(lenght:felt):
end

# Get the `pos`-th checkpoint for `account`.
func Votable_checkpoints{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt, pos:felt)->(checkpoint:Votable_checkpoint):
    alloc_locals
    let(local lenght)=Votable_checkpoints_lenght_storage.read(account)
    with_attr error_message("Votable: checkpoint not exist"):
        is_le(pos,lenght)
    end
    let (checkpoint)=Votable_checkpoint_storage.read(account, pos)
    return(checkpoint)
end

#Get number of checkpoints for `account`.
func Votable_numCheckpoints{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt)->(lenght:felt):
    alloc_locals
    let (local lenght)=Votable_checkpoints_lenght_storage.read(account)
    return(lenght)
end

# Get current votes power for account
func Votable_getVotes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt)->(votes:Uint256):
    alloc_locals
    let (pos)=Votable_checkpoints_lenght_storage.read(account)
    let( checkpoint:Votable_checkpoint)=Votable_checkpoint_storage.read(account, pos)
    return (checkpoint.votes)
end


# Get account vote power for given blocknumber that already mined
func Votable_getPastVotes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt, past_block:felt)->(votes:Uint256):
    alloc_locals
    let (current_block)= get_block_number()
    with_attr error_message("Votable: block not yet mined"):
        assert_lt(past_block, current_block)
    end
    let(last_checkpoints_num)= Votable_checkpoints_lenght_storage.read(account)
    
    with_attr error_message("Votable: account dont have any voting power"):
        is_le(0,last_checkpoints_num)
    end
    if last_checkpoints_num==1:
        let(checkpoint:Votable_checkpoint)=Votable_checkpoint_storage.read(account, last_checkpoints_num)
        return(checkpoint.votes)
    else:
        let (search_complete,past_votes)=_acountCheckpointsLookup(last_checkpoints_num, last_checkpoints_num,account, past_block )
        return(past_votes)
    end

end

# Lookup latest vote power in storage for account
func _acountCheckpointsLookup{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    current_checkpoint:felt, last_checkpoints_num:felt,account, block_number:felt)->(search_result:felt,votes:Uint256):
    alloc_locals

    if current_checkpoint==0:
        return(0,Uint256(0,0))
    else:
        let(checkpoint)=Votable_checkpoint_storage.read(account, current_checkpoint)
        let (local is_block_number_bigger_than_past_block)=is_le(checkpoint.blockNumber,block_number)
        if is_block_number_bigger_than_past_block ==1 :
            let(found_checkpoint:Votable_checkpoint)=Votable_checkpoint_storage.read(account, current_checkpoint+1)
            return(1,found_checkpoint.votes )
        end
    end
   
    let (search_complete, votes)=_acountCheckpointsLookup(current_checkpoint-1, last_checkpoints_num,account,block_number )

    return(search_complete,votes)
end 


# Get total supply for given past block
func Votable_getPastTotalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    past_block:felt)->(votes:Uint256):
    alloc_locals
    let(local checkpoints_lenght)=Votable_total_supply_lenght_storage.read()
    let (current_block)=get_block_number()
    with_attr error_message("Votable: block not yet mined"):
        assert_lt(past_block, current_block)
    end
    let (last_checkpoints_num)=Votable_total_supply_lenght_storage.read()

     if last_checkpoints_num==1:
        let(checkpoint:Votable_checkpoint)=Votable_total_supply_checkpoint_storage.read(last_checkpoints_num)
        return(checkpoint.votes)
    else:
        let (search_complete,past_votes)=_supplyCheckpointsLookup(last_checkpoints_num, last_checkpoints_num, past_block )
        return(past_votes)
    end

end

# Lookup latest vote power in storage for given past block
func _supplyCheckpointsLookup{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    current_checkpoint:felt, last_checkpoints_num:felt, block_number:felt)->(search_result:felt,votes:Uint256):
    alloc_locals

    if current_checkpoint==0:
        return(0,Uint256(0,0))
    else:
        let(checkpoint)=Votable_total_supply_checkpoint_storage.read( current_checkpoint)
        let (local is_block_number_bigger_than_past_block)=is_le(checkpoint.blockNumber,block_number)
        if is_block_number_bigger_than_past_block ==1 :
            let(found_checkpoint:Votable_checkpoint)=Votable_total_supply_checkpoint_storage.read( current_checkpoint+1)
            return(1,found_checkpoint.votes )
        end
    end
    let (search_complete, votes)=_supplyCheckpointsLookup(current_checkpoint-1, last_checkpoints_num,block_number )
    return(search_complete,votes)
end 


# Last total supply checkpoint position
func Votable_getLastTotalSupplyPos{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    )->(pos:felt):
    
    let( pos)=Votable_total_supply_lenght_storage.read()
    return(pos)
end


# Create new checkpoint for account with increased voting power
func Votable_writeCheckpointIncrease{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt,amount:Uint256)->(
    old_weight:Uint256,new_weight:Uint256):
    alloc_locals
    let (pos)=Votable_checkpoints_lenght_storage.read(account)
    let(old_checkpoint:Votable_checkpoint)= Votable_checkpoint_storage.read(account,pos)
    let (current_block)=get_block_number()
    local new_pos=pos+1
    let (local new_weight)=uint256_checked_add( old_checkpoint.votes,amount)
    local new_checkpoint:Votable_checkpoint=Votable_checkpoint(current_block,new_weight)
    Votable_checkpoints_lenght_storage.write(account,new_pos)
    Votable_checkpoint_storage.write(account,new_pos,new_checkpoint)
    return(old_checkpoint.votes, new_weight)

end

# Create new checkpoint for account with decreased voting power
func Votable_writeCheckpointDecrease{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt,amount:Uint256)->(
    old_weight:Uint256,new_weight:Uint256):
    alloc_locals
    let (pos)=Votable_checkpoints_lenght_storage.read(account)
    let(old_checkpoint:Votable_checkpoint)= Votable_checkpoint_storage.read(account,pos)
    let (current_block)=get_block_number()
    local new_pos=pos+1
    let  (local new_weight)=uint256_checked_sub_le(amount, old_checkpoint.votes)
    local new_checkpoint:Votable_checkpoint=Votable_checkpoint(current_block,new_weight)
    Votable_checkpoints_lenght_storage.write(account,new_pos)
    Votable_checkpoint_storage.write(account,new_pos,new_checkpoint)
    return(old_checkpoint.votes, new_weight)

end


# Change account voting power after transfer function
func Votable_afterTransfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient:felt,amount:Uint256):
    let (caller)=get_caller_address()
    Votable_moveVotingPower(caller,recipient,amount)
    return()
end

# Change account voting power after transferFrom function
func Votable_afterTransferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sender:felt,recipient:felt,amount:Uint256):
    Votable_moveVotingPower(sender,recipient,amount)
    return()
end

# Change  voting power  for two acounts after transfer 
func Votable_moveVotingPower{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    src:felt,dst:felt,amount:Uint256):
    alloc_locals
    let (amount_not_zero)=uint256_lt(Uint256(0,0),amount)
    if amount_not_zero==1:
        with_attr error_message("Votable: adress cannot be zero"):
            assert_not_zero(src)
        end

        let ( old_weight_src,new_weight_src)=Votable_writeCheckpointDecrease(src, amount)
        let (address_not_zero)=is_not_zero(dst)

        if address_not_zero==1:
            let ( old_weight_dst,new_weight_dst)=Votable_writeCheckpointIncrease(src, amount)
            tempvar syscall_ptr :felt* = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            tempvar syscall_ptr :felt* = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
        tempvar syscall_ptr :felt* = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr :felt* = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    return()

end

# Create new checkpoint for total supply  
func Votable_writeCheckpointTotalsupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    total_supply:Uint256):
    alloc_locals

    let (pos)=Votable_total_supply_lenght_storage.read()
    let (current_block)=get_block_number()
    local new_pos=pos+1
    local new_checkpoint:Votable_checkpoint=Votable_checkpoint(current_block,total_supply)
    Votable_total_supply_lenght_storage.write(new_pos)
    Votable_total_supply_checkpoint_storage.write(new_pos,new_checkpoint)

    return()
end