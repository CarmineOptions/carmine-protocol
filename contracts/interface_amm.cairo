%lang starknet

from types import Address, OptionType, Math64x61_, OptionSide, Int, Option, Bool
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
        limit_desired_price: Math64x61_, 
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
        limit_desired_price: Math64x61_, 
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
}