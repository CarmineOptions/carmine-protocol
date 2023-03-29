// Holds information about pool liquidity providers. ERC20 contract
// univ2 pair token: https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol

// taken from:
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.2.1 (token/erc20/ERC20_Mintable.cairo)

// It is also adjusted for the purpose of being options
// Notes
// - transfering any capital happens outside of this token (on the AMM contract side)
// - Ownable replaced with Proxy Admin


%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_timestamp
from openzeppelin.upgrades.library import Proxy
from openzeppelin.token.erc20.library import ERC20

from constants import (
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    TRADE_SIDE_SHORT,
    get_opposite_side,
)
from helpers import max
from types import (Bool, Math64x61_, OptionType, OptionSide, Int, Address, Option)


@storage_var
func option_token_quote_token_address() -> (quote_token_address: felt) {
}

@storage_var
func option_token_base_token_address() -> (base_token_address: felt) {
}

@storage_var
func option_token_option_type() -> (option_type: felt) {
}

@storage_var
func option_token_strike_price() -> (strike_price: felt) {
}

@storage_var
func option_token_maturity() -> (maturity: felt) {
}

@storage_var
func option_token_side() -> (side: felt) {
}

// owner should be main contract
@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    name: felt,
    symbol: felt,
    decimals: felt,
    initial_supply: Uint256,
    recipient: felt,
    proxy_admin: felt,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionSide,
    strike_price: Math64x61_,
    maturity: Int,
    side: OptionSide,
) {
    // inputs below admin are inputs needed for the option definition
    ERC20.initializer(name, symbol, decimals);
    ERC20._mint(recipient, initial_supply);
    Proxy.initializer(proxy_admin);

    option_token_quote_token_address.write(quote_token_address);
    option_token_base_token_address.write(base_token_address);
    option_token_option_type.write(option_type);
    option_token_strike_price.write(strike_price);
    option_token_maturity.write(maturity);
    option_token_side.write(side);
    return ();
}

@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_implementation: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(new_implementation);
    return ();
}

//
// Getters
//

@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    let (name) = ERC20.name();
    return (name,);
}

@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    symbol: felt
) {
    let (symbol) = ERC20.symbol();
    return (symbol,);
}

@view
func totalSupply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    totalSupply: Uint256
) {
    let (totalSupply: Uint256) = ERC20.total_supply();
    return (totalSupply,);
}

@view
func decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    decimals: felt
) {
    let (decimals) = ERC20.decimals();
    return (decimals,);
}

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt
) -> (balance: Uint256) {
    let (balance: Uint256) = ERC20.balance_of(account);
    return (balance,);
}

@view
func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt
) -> (remaining: Uint256) {
    let (remaining: Uint256) = ERC20.allowance(owner, spender);
    return (remaining,);
}

@view
func owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
    let (owner: felt) = Ownable.owner();
    return (owner,);
}

@view
func quote_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (quote_token: felt) {
    let (quote_token_address: felt) = option_token_quote_token_address.read();
    return (quote_token_address,);
}

@view
func base_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (base_token: felt) {
    let (base_token_address: felt) = option_token_base_token_address.read();
    return (base_token_address,);
}

@view
func option_type{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    option_type: felt
) {
    let (option_type: felt) = option_token_option_type.read();
    return (option_type,);
}

@view
func strike_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    strike_price: felt
) {
    let (strike_price: felt) = option_token_strike_price.read();
    return (strike_price,);
}

@view
func maturity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    maturity: felt
) {
    let (maturity: felt) = option_token_maturity.read();
    return (maturity,);
}

@view
func side{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (side: felt) {
    let (side: felt) = option_token_side.read();
    return (side,);
}

//
// Externals
//

@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) -> (success: felt) {
    ERC20.transfer(recipient, amount);
    return (TRUE,);
}

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) -> (success: felt) {
    ERC20.transfer_from(sender, recipient, amount);
    return (TRUE,);
}

@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) -> (success: felt) {
    ERC20.approve(spender, amount);
    return (TRUE,);
}

@external
func increaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, added_value: Uint256
) -> (success: felt) {
    ERC20.increase_allowance(spender, added_value);
    return (TRUE,);
}

@external
func decreaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, subtracted_value: Uint256
) -> (success: felt) {
    ERC20.decrease_allowance(spender, subtracted_value);
    return (TRUE,);
}

@external
func mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    to: felt, amount: Uint256
) {
    Proxy.assert_only_admin();
    ERC20._mint(to, amount);
    return ();
}

@external
func burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt, amount: Uint256
) {
    Proxy.assert_only_admin();
    ERC20._burn(account, amount);
    return ();
}
