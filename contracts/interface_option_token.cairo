# according to https://www.cairo-lang.org/docs/hello_starknet/calling_contracts.html
# we have to use an extra interface like this to call (any) external contract
# adapted from OpenZeppelin Contracts for Cairo v0.3.0 (token/erc20/IERC20.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IOptionToken:
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

    func owner() -> (owner: felt):
    end

    func underlying_asset_address() -> (underlying_asset: felt):
    end

    func option_type() -> (option_type: felt):
    end

    func strike_price() -> (strike_price: felt):
    end

    func maturity() -> (maturity: felt):
    end

    func side() -> (side: felt):
    end

    func get_value_for_holder(final_price: felt, amount: felt) -> (holder_value: felt):
    end

    func get_value_for_liquidity_pool(
            final_price: felt,
            amount: felt
        ) -> (liqudity_pool_value: felt):
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

    func increaseAllowance(spender: felt, added_value: Uint256) -> (success: felt):
    end

    func decreaseAllowance(spender: felt, subtracted_value: Uint256) -> (success: felt):
    end

    func mint(to: felt, amount: Uint256):
    end

    func burn(account: felt, amount: Uint256):
    end

    func transferOwnership(newOwner: felt):
    end

    func renounceOwnership():
    end

end
