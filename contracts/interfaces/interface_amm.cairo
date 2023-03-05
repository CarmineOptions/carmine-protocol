%lang starknet

from contracts.types import (
    Address, OptionType, Math64x61_, OptionSide, Int, Option, Bool, OptionWithPremia, PoolInfo,
    UserPoolInfo, Pool
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
        quote_token_address: Address,
        base_token_address: Address,
        option_type: OptionType,
        lptoken_address: Address,
        pooled_token_addr: Address,
        volatility_adjustment_speed: Math64x61_,
        max_lpool_bal: Uint256
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


    func get_lptokens_for_underlying(pooled_token_addr: Address, underlying_amt: Uint256) -> (
        lpt_amt: Uint256
    ) {
    }


    func get_underlying_for_lptokens(pooled_token_addr: Address, lpt_amt: Uint256) -> (
        underlying_amt: Uint256
    ) {
    }


    func get_available_lptoken_addresses(order_i: Int) -> (lptoken_address: Address) {
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


    func get_value_of_position(
        option: Option,
        position_size: Math64x61_,
        option_type: OptionType,
        current_volatility: Math64x61_
    ) -> (position_value: Math64x61_){
    }


    func get_all_poolinfo() -> (pool_info_len: felt, pool_info: PoolInfo*) {
    }


    func get_option_info_from_addresses(
        lptoken_address: Address,
        option_token_address: Address
    ) -> (option: Option) {
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


    func expire_option_token_for_pool(
        lptoken_address: Address,
        option_side: OptionSide,
        strike_price: Math64x61_,
        maturity: Int,
    ) {
    }


    func getAdmin(){
    }

    func set_max_option_size_percent_of_voladjspd(max_opt_size_as_perc_of_vol_adjspd: Int){
    }

    func get_max_option_size_percent_of_voladjspd() -> (res: Int){
    }

    func get_lpool_balance(lptoken_address: Address) -> (res: Uint256) {
    }

    func get_max_lpool_balance(pooled_token_addr: Address) -> (max_balance: Uint256){
    }

    func set_max_lpool_balance(pooled_token_addr: Address, max_lpool_bal: Uint256){
    }

    func get_pool_locked_capital(lptoken_address: Address) -> (res: Uint256) {
    }


    func get_available_options(lptoken_address: Address, order_i: Int) -> (option: Option) {
    }


    func get_available_options_usable_index(lptoken_address: Address, starting_index: Int) -> (
        usable_index: Int
    ) {
    }


    func get_lptoken_address_for_given_option(
        quote_token_address: Address,
        base_token_address: Address,
        option_type: OptionType
    ) -> (lptoken_address: Address) {
    }


    func get_pool_definition_from_lptoken_address(lptoken_addres: Address) -> (pool: Pool) {
    }


    func get_option_type(lptoken_address: Address) -> (option_type: OptionType) {
    }


    func get_pool_volatility_separate(
        lptoken_address: Address, maturity: Int, strike_price: Math64x61_
    ) -> (pool_volatility: Math64x61_) {
    }


    func get_underlying_token_address(lptoken_address: Address) -> (
        underlying_token_address_: Address
    ) {
    }


    func get_available_lptoken_addresses_usable_index(starting_index: Int) -> (usable_index: Int) {
    }


    func get_pool_volatility_adjustment_speed(lptoken_address: Address) -> (res: Math64x61_) {
    }


    func set_pool_volatility_adjustment_speed_external(
        lptoken_address: Address, new_speed: Math64x61_
    ) -> () {
    }


    func get_pool_volatility(lptoken_address: Address, maturity: Int) -> (
        pool_volatility: Math64x61_
    ) {
    }


    func get_pool_volatility_auto(
        lptoken_address: Address, maturity: Int, strike_price: Math64x61_
    ) -> (pool_volatility: Math64x61_) {
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


    func black_scholes(
        sigma: felt,
        time_till_maturity_annualized: felt,
        strike_price: felt,
        underlying_price: felt,
        risk_free_rate_annualized: felt,
    ) -> (call_premia: felt, put_premia: felt) {
    }


    func empiric_median_price(key: felt) -> (price: Math64x61_) {
    }


    func initializer(proxy_admin: felt) {
    }


    func upgrade(new_implementation: felt) {
    }


    func setAdmin(address: felt) {
    }


    func getImplementationHash() -> (implementation_hash: felt) {
    }

}