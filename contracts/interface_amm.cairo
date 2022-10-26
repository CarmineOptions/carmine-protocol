%lang starknet

from types import Address, OptionType, Math64x61_, OptionSide, Int
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IAMM {
    func trade_open(
        option_type : OptionType,
        strike_price : Math64x61_,
        maturity : Int,
        option_side : OptionSide,
        option_size : Math64x61_,
        // underlying_asset
        quote_token_address: Address,
        base_token_address: Address,
    ) -> (premia : Math64x61_) {
    }


    func trade_close(
        option_type : OptionType,
        strike_price : Math64x61_,
        maturity : Int,
        option_side : OptionSide,
        option_size : Math64x61_,
        // underlying_asset
        quote_token_address: Address,
        base_token_address: Address,
    ) -> (premia : Math64x61_) {
    }


    func trade_settle(
        option_type : OptionType,
        strike_price : Math64x61_,
        maturity : Int,
        option_side : OptionSide,
        option_size : Math64x61_,
        // underlying_asset
        quote_token_address: Address,
        base_token_address: Address,
    ) -> (premia : Math64x61_) {
    }


    func withdraw_liquidity(
        pooled_token_addr: Address,
        quote_token_address: Address,
        base_token_address: Address,
        option_type: OptionType,
        lp_token_amount: Uint256,
    ) {
    }

    func get_unlocked_capital(
        lptoken_address: Address
    ) -> (unlocked_capital: Math64x61_) {
    }
}