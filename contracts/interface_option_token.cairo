// according to https://www.cairo-lang.org/docs/hello_starknet/calling_contracts.html
// we have to use an extra interface like this to call (any) external contract
// adapted from OpenZeppelin Contracts for Cairo v0.3.0 (token/erc20/IERC20.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IOptionToken {
    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func decimals() -> (decimals: felt) {
    }

    func totalSupply() -> (totalSupply: Uint256) {
    }

    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256) {
    }

    func owner() -> (owner: felt) {
    }

    func underlying_asset_address() -> (underlying_asset: felt) {
    }

    func option_type() -> (option_type: felt) {
    }

    func strike_price() -> (strike_price: felt) {
    }

    func maturity() -> (maturity: felt) {
    }

    func side() -> (side: felt) {
    }

    func get_value_for_holder(final_price: felt, amount: felt) -> (holder_value: felt) {
    }

    func get_value_for_liquidity_pool(final_price: felt, amount: felt) -> (
        liqudity_pool_value: felt
    ) {
    }

    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }

    func increaseAllowance(spender: felt, added_value: Uint256) -> (success: felt) {
    }

    func decreaseAllowance(spender: felt, subtracted_value: Uint256) -> (success: felt) {
    }

    func mint(to: felt, amount: Uint256) {
    }

    func burn(account: felt, amount: Uint256) {
    }

    func transferOwnership(newOwner: felt) {
    }

    func renounceOwnership() {
    }
}
