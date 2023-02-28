%lang starknet

from contracts.types import (
    Address, OptionType, Math64x61_, OptionSide, Int, Option, Bool, OptionWithPremia, PoolInfo,
    UserPoolInfo
)
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IAMM {
    func trade_open(
        option_type : OptionType,
        strike_price : Math64x61_,
        maturity : Int,
        option_side : OptionSide,
        option_size : Int,
        quote_token_address: Address,
        base_token_address: Address,
        limit_total_premia: Math64x61_, 
        tx_deadline: Int,
    ) -> (premia : Math64x61_) {
    }


    func trade_close(
        option_type : OptionType,
        strike_price : Math64x61_,
        maturity : Int,
        option_side : OptionSide,
        option_size : Int,
        quote_token_address: Address,
        base_token_address: Address,
        limit_total_premia: Math64x61_, 
        tx_deadline: Int,
    ) -> (premia : Math64x61_) {
    }


    func trade_settle(
        option_type : OptionType,
        strike_price : Math64x61_,
        maturity : Int,
        option_side : OptionSide,
        option_size : Int,
        quote_token_address: Address,
        base_token_address: Address,
    ) {
    }


    func is_option_available(
        lptoken_address: Address, option_side: OptionSide, strike_price: Math64x61_, maturity: Int
    ) -> (option_availability: felt) {
    }

    
    func set_trading_halt(new_status: Bool) -> () {
    }


    func get_trading_halt() -> (res: Bool) {
    }

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
        lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Math64x61_
    ) -> (option_token_address: Address) {
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


    func get_option_with_position_of_user(user_address : Address) -> (
        array_len : felt, array : felt*
    ) {
    }


    func get_all_lptoken_addresses() -> (array_len : felt, array : Address*) {
    }


    func get_value_of_pool_position(lptoken_address: Address) -> (res: Math64x61_) {
    }


    func get_all_poolinfo() -> (pool_info_len: felt, pool_info: PoolInfo*) {
    }


    func get_user_pool_infos(user: Address) -> (
        user_pool_infos_len: felt,
        user_pool_infos: UserPoolInfo*
    ) {
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


    func get_unlocked_capital(lptoken_address: Address) -> (unlocked_capital: Uint256) {
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


    func get_lpool_balance(lptoken_address: Address) -> (res: Uint256) {
    }


    func get_pool_locked_capital(lptoken_address: Address) -> (res: Uint256) {
    }


    func get_pool_volatility(lptoken_address: Address, maturity: Int) -> (
        pool_volatility: Math64x61_
    ) {
    }


    func get_option_position(
        lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Math64x61_
    ) -> (
        res: Int
    ) {
    }

    func get_total_premia(
        option: Option,
        lptoken_address: Address,
        position_size: Uint256,
        is_closing: Bool,
    ) -> (
        total_premia_before_fees: Math64x61_,
        total_premia_including_fees: Math64x61_
    ) {
    }
}