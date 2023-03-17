// SPDX-License-Identifier: MIT
// adapted from:
// OpenZeppelin Contracts for Cairo v0.6.1 (token/erc20/presets/IERC20Upgradeable.cairo)
// Interface for the non-transferable governance token contract
// which is upgradeable through governance

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IGovernanceToken {
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

    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func mint(to: felt, amount: Uint256) {
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }

    func increaseAllowance(spender: felt, added_value: Uint256) -> (success: felt) {
    }

    func decreaseAllowance(spender: felt, subtracted_value: Uint256) -> (success: felt) {
    }

    func pause() {
    }

    func unpause() {
    }

    func upgrade(new_implementation: felt) {
    }

    func initializer(
        name: felt,
        symbol: felt,
        decimals: felt,
        initial_supply: Uint256,
        recipient: felt,
        proxy_admin: felt
    ) {
    }

}
