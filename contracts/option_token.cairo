// Holds information about pool liquidity providers. ERC20 contract
// univ2 pair token: https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol

// taken from:
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.2.1 (token/erc20/ERC20_Mintable.cairo)

// It is also adjusted for the purpose of being options
// Notes
// - transfering any capital happens outside of this token (on an LP contract side
// -

%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_timestamp

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.token.erc20.library import ERC20

from contracts.constants import (
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    TRADE_SIDE_SHORT,
    get_opposite_side,
)
from contracts.helpers import max

@storage_var
func option_token_underlying_asset_address() -> (underlying_asset_address: felt) {
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

namespace OptionToken {
    // owner should be main contract
    @constructor
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        name: felt,
        symbol: felt,
        decimals: felt,
        initial_supply: Uint256,
        recipient: felt,
        owner: felt,
        underlying_asset_address: felt,
        option_type: felt,
        strike_price: felt,
        maturity: felt,
        side: felt,
    ) {
        // inputs bellow owner are inputs needed for the option definition
        ERC20.initializer(name, symbol, decimals);
        ERC20._mint(recipient, initial_supply);
        Ownable.initializer(owner);

        option_token_underlying_asset_address.write(underlying_asset_address);
        option_token_option_type.write(option_type);
        option_token_strike_price.write(strike_price);
        option_token_maturity.write(maturity);
        option_token_side.write(side);
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
    func underlying_asset_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (underlying_asset: felt) {
        let (underlying_asset_address: felt) = option_token_underlying_asset_address.read();
        return (underlying_asset_address,);
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

    @view
    func get_value_for_holder{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        final_price: felt, amount: felt
    ) -> (holder_value: felt) {
        // Make sure the number coming out of this function are used in a relation with correct
        // currencies.

        // FIXME: validate that the code below makes LP better off in case of rounding values

        // in terms of base token (ETH in case ETH/USD)
        let option_size = amount;

        // current_timestamp is in number of seconds... unix timestamp
        let (current_timestamp) = get_block_timestamp();
        let (maturity_timestamp) = option_token_maturity.read();

        let is_mature = is_le(maturity_timestamp, current_timestamp);

        if (is_not_yet_mature == TRUE) {
            with_attr error_message("Option is not yet mature.") {
                assert is_mature = 1;
            }

            let (option_type) = option_token_option_type.read();
            let (option_side) = option_token_side.read();
            let (strike_price) = option_token_strike_price.read();

            if (option_type == OPTION_CALL) {
                // The sum of the following two cases has to equal to the size of the locked capital
                // which is in base tokens (ETH in case ETH/USD)

                let (final_minus_strike) = final_price - strike_price;
                let (best_case_in_quote_call_long) = max(0, final_minus_strike);
                let (best_case_in_base_call_long) = best_case_in_quote_call_long / final_price;
                let (
                    best_case_in_base_call_long_scaled
                ) = option_size * best_case_in_base_call_long;

                if (option_side == TRADE_SIDE_LONG) {
                    // user is buyer and gets money only if the strike was hit
                    // in case of a call option all cash is settled in base tokens (ETH in case ETH/USD)
                    // and the final_price and option_token_strike_price are in terms of quote token

                    return best_case_in_base_call_long_scaled;
                } else {
                    // user is seller (underwriter) and gets money everytime, but size of the cash
                    // depends on the final price and the strike
                    // in case of a call option all cash is settled in base tokens (ETH in case ETH/USD)
                    // and the final_price and option_token_strike_price are in terms of quote token
                    // and option_size in terms of base token

                    return option_size - best_case_in_base_call_long_scaled;
                }
            } else {
                // The sum of the following two cases has to equal to the size of the locked capital
                // which is in quote tokens (USD in case ETH/USD)

                let (strike_minus_final) = strike_price - final_price;
                let (best_case_in_quote_put_long) = max(0, strike_minus_final);
                let (
                    best_case_in_quote_put_long_scaled
                ) = option_size * best_case_in_quote_put_long;

                if (side == long) {
                    // user is buyer and gets money only if the strike was hit
                    // in case of a put option all cash is settled in quote tokens (USD in case ETH/USD)
                    // and the final_price and option_token_strike_price are in terms of quote token (same token)
                    return best_case_in_quote_put_long_scaled;
                } else {
                    // user is seller (underwriter) and gets money everytime unless the final price is 0,
                    // but size of the cash depends on the final price and the strike
                    // in case of a put option all cash is settled in quote tokens (USD in case ETH/USD)
                    // and the final_price and option_token_strike_price are in terms of quote token (same token)
                    // and option_size in terms of base token
                    // FIXME: extra test the scenario that the currencies are of correct type (base/quote)

                    let (option_size_in_quote) = option_size * strike_price;

                    return option_size_in_quote - best_case_in_quote_put_long_scaled;
                }
            }

            return ();
        }

        @view
        func get_value_for_liquidity_pool{
            syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
        }(final_price: felt, amount: felt) -> (liqudity_pool_value: felt) {
            // FIXME: deal with correct types -> felt vs Math_64x61 vs uint256

            let (side) = option_token_side.read();
            let (option_type) = option_token_option_type.read();

            let (opposite_side) = get_opposite_side(side);
            let (holder_value) = get_value_for_holder(final_price);

            // liquidity pool value is locked capital minus holder value
            // options_size = amount  # in terms of base token (ETH in case ETH/USD)
            if (option_type == OPTION_CALL) {
                // holder_value is already in the same currency as amount... in base token
                let (call_lp_value) = amount - holder_value;
                return (call_lp_value,);
            }

            // holder_value is already in the same currency as amount_in_quote... in quote token
            let (amount_in_quote) = amount * final_price;
            let (put_lp_value) = amount_in_quote - holder_value;
            return (put_lp_value,);
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
            Ownable.assert_only_owner();
            ERC20._mint(to, amount);
            return ();
        }

        @external
        func burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            account: felt, amount: Uint256
        ) {
            // FIXME: burn should also unfreeze the locked capital of the liquidity pool...
            // FIXME: hence burn only through LP contact
            Ownable.assert_only_owner();
            ERC20._burn(account, amount);
            return ();
        }

        @external
        func transferOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            newOwner: felt
        ) {
            // FIXME: as per note in the burn func... tranfering ownership should not be allowed or should
            // unfreeze the locked capital in LP since if ownership is transfered the burn method could be called
            // this is potentiall leak
            Ownable.transfer_ownership(newOwner);
            return ();
        }

        @external
        func renounceOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
            Ownable.renounce_ownership();
            return ();
        }
    }
}
