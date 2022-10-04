// according to https://www.cairo-lang.org/docs/hello_starknet/calling_contracts.html
// we have to use an extra interface like this to call (any) external contract
// adapted from OpenZeppelin Contracts for Cairo v0.3.0 (token/erc20/IERC20.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ILiquidityPool {
    // FIXME: we might not need all of the following function...
    // FIXME: and some of them are not external at the moment

    func add_lptoken(
        quote_token_address: felt,
        base_token_address: felt,
        option_type: felt,
        lptoken_address: felt
    ){
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

    func deposit_lp(pooled_token_addr: felt, amt: Uint256) {
    }

    func withdraw_lp(pooled_token_addr: felt, amt: Uint256) {
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

    func expire_option_token_for_user(
        amount: felt, option_type: felt, option_side: felt, strike_price: felt
    ) {
    }

    func expire_option_token_for_pool(
        amount: felt, option_type: felt, option_side: felt, strike_price: felt
    ) {
    }
}
