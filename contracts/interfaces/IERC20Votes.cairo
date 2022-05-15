# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.1.0 (token/erc20/interfaces/IERC20.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256
from contracts.library.votable import Votable_checkpoint

@contract_interface
namespace IERC20Votes:
    func name() -> (name: felt):
    end

    func symbol() -> (symbol: felt):
    end

    func decimals() -> (decimals: felt):
    end

    func totalSupply() -> (totalSupply: Uint256):
    end

    func balanceOf(account: felt) -> (balance: Uint256):
    end

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256):
    end

    func checkpoints(account:felt,pos:felt)->(checkpoint:Votable_checkpoint):
    end

    func numCheckpoints(account:felt)->(pos:felt):
    end

    func getVotes(account:felt)->(votes:Uint256):
    end

    func getPastTotalSupply(pos:felt)->(votes:Uint256):
    end

    func getLastTotalSupplyPos()->(pos:felt):
    end

    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end

    func transferFrom(
            sender: felt, 
            recipient: felt, 
            amount: Uint256
        ) -> (success: felt):
    end

    func approve(spender: felt, amount: Uint256) -> (success: felt):
    end
end