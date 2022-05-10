# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts 

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.uint256 import Uint256

from library.ERC20 import (
    ERC20_name,
    ERC20_symbol,
    ERC20_totalSupply,
    ERC20_decimals,
    ERC20_balanceOf,
    ERC20_allowance,

    ERC20_initializer,
    ERC20_approve,
    ERC20_increaseAllowance,
    ERC20_decreaseAllowance,
    ERC20_transfer,
    ERC20_transferFrom,
    ERC20_mint
)

from library.votable import(
    Votable_checkpoint,
    Votable_checkpoint_storage,
    Votable_total_supply_checkpoint_storage,
    Votable_total_supply_lenght_storage,
    Votable_checkpoints_lenght_storage,
    Votable_checkpoints,
    Votable_numCheckpoints,
    Votable_getVotes,
    Votable_getPastTotalSupply,
    Votable_writeCheckpointIncrease,
    Votable_writeCheckpointDecrease,
    Votable_moveVotingPower,
    Votable_writeCheckpointTotalsupply,
    Votable_getLastTotalSupplyPos,
    Votable_afterTransferFrom,
    Votable_afterTransfer,
    Votable_checkpoint
)

@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        decimals: felt,
        initial_supply: Uint256,
        recipient: felt
    ):
    ERC20_initializer(name, symbol, decimals)
    ERC20_mint(recipient, initial_supply)
    Votable_writeCheckpointTotalsupply(initial_supply)
    Votable_writeCheckpointIncrease(recipient,initial_supply)

    return ()
end

#
# Getters
#

@view
func name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (name: felt):
    let (name) = ERC20_name()
    return (name)
end

@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = ERC20_symbol()
    return (symbol)
end

@view
func totalSupply{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (totalSupply: Uint256):
    let (totalSupply: Uint256) = ERC20_totalSupply()
    return (totalSupply)
end

@view
func decimals{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (decimals: felt):
    let (decimals) = ERC20_decimals()
    return (decimals)
end

@view
func balanceOf{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (balance: Uint256):
    let (balance: Uint256) = ERC20_balanceOf(account)
    return (balance)
end

@view
func allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt, spender: felt) -> (remaining: Uint256):
    let (remaining: Uint256) = ERC20_allowance(owner, spender)
    return (remaining)
end

#dev Get the `pos`-th checkpoint for `account`.
@view
func checkpoints{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account:felt,pos:felt)->(checkpoint:Votable_checkpoint):
    
    let (checkpoint)=Votable_checkpoints(account,pos)
    return(checkpoint)
end

#Get number of checkpoints for `account`.
@view
func numCheckpoints{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account:felt)->(pos:felt):
    
    let (pos)=Votable_numCheckpoints(account)
    return(pos)
end

#Gets the current votes balance for `account`
@view
func getVotes{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account:felt)->(votes:Uint256):

    let(votes)=Votable_getVotes(account)
    return (votes)
end


#Gets the totalvotes for given pos
@view
func getPastTotalSupply{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pos:felt)->(votes:Uint256):

    let(votes)=Votable_getPastTotalSupply(pos)
    return (votes)
end

@view
func getLastTotalSupplyPos{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }()->(pos:felt):

    let(pos)=Votable_getLastTotalSupplyPos()
    return (pos)
end

#
# Externals
#

@external
func transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256) -> (success: felt):
    ERC20_transfer(recipient, amount)
    Votable_afterTransfer(recipient,amount)
    return (TRUE)
end

@external
func transferFrom{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        sender: felt, 
        recipient: felt, 
        amount: Uint256
    ) -> (success: felt):
    ERC20_transferFrom(sender, recipient, amount)
    Votable_afterTransferFrom(sender, recipient, amount)
    return (TRUE)
end

@external
func approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, amount: Uint256) -> (success: felt):
    ERC20_approve(spender, amount)
    return (TRUE)
end

@external
func increaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, added_value: Uint256) -> (success: felt):
    ERC20_increaseAllowance(spender, added_value)
    return (TRUE)
end

@external
func decreaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, subtracted_value: Uint256) -> (success: felt):
    ERC20_decreaseAllowance(spender, subtracted_value)
    return (TRUE)
end
