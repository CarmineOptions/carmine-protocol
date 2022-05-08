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

# Mapping that stores checkpoint for given account and new snapshots
@storage_var
func Votable_checkpoint_storage(account:felt,i:felt)->(checkpoint:Votable_checkpoint):
end

# Mapping that stores totalsupply for each snapshot 
@storage_var
func Votable_total_supply_checkpoint_storage(i:felt)->(checkpoint:Votable_checkpoint):
end

# Mapping that stores last number of snapshot for totalsupply
@storage_var
func Votable_total_supply_lenght_storage()->(lenght:felt):
end

# Mapping that stores last number of snapshot for each account
@storage_var
func Votable_checkpoints_lenght_storage(account:felt)->(lenght:felt):
end


func Votable_checkpoints{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt, pos:felt)->(checkpoint:Votable_checkpoint):
    alloc_locals
    let(local lenght)=Votable_checkpoints_lenght_storage.read(account)
    with_attr error_message("checkpoint not exist"):
        is_le(pos,lenght)
    end
    let (checkpoint)=Votable_checkpoint_storage.read(account, pos)
    return(checkpoint)
end

func Votable_numCheckpoints{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt)->(lenght:felt):
    alloc_locals
    let (local lenght)=Votable_checkpoints_lenght_storage.read(account)
    return(lenght)
end


func Votable_getVotes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt)->(votes:Uint256):
    alloc_locals
    let (pos)=Votable_checkpoints_lenght_storage.read(account)
    let( checkpoint:Votable_checkpoint)=Votable_checkpoint_storage.read(account, pos)
    return (checkpoint.votes)
end



func Votable_getPastTotalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    pos:felt)->(votes:Uint256):
    alloc_locals
    let(local lenght)=Votable_total_supply_lenght_storage.read()
    with_attr error_message("checkpoint not exist"):
        is_le(pos,lenght)
    end
    let (total_supply_checkpoint:Votable_checkpoint)=Votable_total_supply_checkpoint_storage.read(pos)
    return(total_supply_checkpoint.votes)
end

func Votable_getLastTotalSupplyPos{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    )->(pos:felt):
    
    let( pos)=Votable_total_supply_lenght_storage.read()
    return(pos)
end


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


func Votable_afterTransfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient:felt,amount:Uint256):
    let (caller)=get_caller_address()
    Votable_moveVotingPower(caller,recipient,amount)
    return()
end

func Votable_afterTransferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sender:felt,recipient:felt,amount:Uint256):
    Votable_moveVotingPower(sender,recipient,amount)
    return()
end

func Votable_moveVotingPower{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    src:felt,dst:felt,amount:Uint256):
    alloc_locals
    let (amount_not_zero)=uint256_lt(Uint256(0,0),amount)
    if amount_not_zero==1:
        with_attr error_message("adress cannot be zero"):
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