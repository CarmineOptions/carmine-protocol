// according to https://www.cairo-lang.org/docs/hello_starknet/calling_contracts.html
// we have to use an extra interface like this to call (any) external contract
// adapted from OpenZeppelin Contracts for Cairo v0.3.0 (token/erc20/IERC20.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256
from types import Address, OptionType, Math64x61_, OptionSide, Int

@contract_interface
namespace ILiquidityPool {
    // FIXME: validate that the interface is correctly created

    func add_lptoken(
        quote_token_address: felt,
        base_token_address: felt,
        option_type: felt,
        lptoken_address: felt
    ){
    }


    func add_option(
        option_side: OptionSide,
        maturity: Int,
        strike_price: Math64x61_,
        quote_token_address: Address,
        base_token_address: Address,
        option_type: OptionType,
        lptoken_address: Address,
        option_token_address_: Address,
        initial_volatility: Math64x61_
    ) {
    }


    func get_option_token_address(
        option_side: felt, option_type: felt, maturity: felt, strike_price: felt
    ) {
    }


    func get_lptokens_for_underlying(pooled_token_addr: felt, underlying_amt: Uint256) -> (
        lpt_amt: Uint256
    ) {
    }


    func get_underlying_for_lptokens(pooled_token_addr: felt, lpt_amt: Uint256) -> (
        underlying_amt: Uint256
    ) {
    }


    func get_available_lptoken_addresses(order_i: Int) -> (lptoken_address: Address) {
    }


    // FIXME: drop this function down the line
    func set_available_lptoken_addresses(order_i: Int, lptoken_address: Address) -> (
        lptoken_address: Address
    ) {
    }


    func get_all_options(lptoken_address: Address) -> (array_len : felt, array : felt*) {
    }


    func get_all_non_expired_options_with_premia(lptoken_address: Address) -> (
        array_len : felt, array : felt*
    ) {
    }


    func get_all_lptoken_addresses() -> (array_len : felt, array : Address*) {
    }


    func deposit_liquidity(
        pooled_token_addr: Address,
        quote_token_address: Address,
        base_token_address: Address,
        option_type: OptionType,
        amount: Uint256
    ) {
    }


    func withdraw_liquidity(
        pooled_token_addr: Address,
        quote_token_address: Address,
        base_token_address: Address,
        option_type: OptionType,
        lp_token_amount: Uint256
    ) {
    }


    func get_unlocked_capital(lptoken_address: Address) -> (unlocked_capital: Math64x61_) {
    }


    func mint_option_token(
        currency_address: felt,
        option_token_address: felt,
        amount: felt,
        option_side: felt,
        option_type: felt,
        maturity: felt,
        strike: felt,
        premia: felt,
        fees: felt,
        underlying_price: felt,
    ) {
    }


    func burn_option_token(
        option_token_address: felt,
        amount: felt,
        option_side: felt,
        option_type: felt,
        maturity: felt,
        strike: felt,
        premia: felt,
        fees: felt,
        underlying_price: felt,
    ) {
    }


    func expire_option_token(
        currency_address: felt,
        option_token_address: felt,
        option_type: felt,
        option_side: felt,
        strike_price: felt,
        underlying_price: felt,
        amount: felt,
        maturity: felt,
    ) {
    }


    func expire_option_token_for_pool(
        lptoken_address: Address,
        option_side: OptionSide,
        strike_price: Math64x61_,
        maturity: Int,
    ) {
    }


    func getAdmin(){
    }


    func get_lpool_balance(lptoken_address: Address) -> (res: Math64x61_) {
    }


    func get_pool_locked_capital(lptoken_address: Address) -> (res: Math64x61_) {
    }


    func get_pool_volatility(lptoken_address: Address, maturity: Int) -> (
        pool_volatility: Math64x61_
    ) {
    }


    func get_pools_option_position(
        lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Math64x61_
    ) -> (
        res: Math64x61_
    ) {
    }
}
