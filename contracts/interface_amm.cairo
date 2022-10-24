%lang starknet

from types import Address, OptionType, Math64x61_, OptionSide, Int

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
}