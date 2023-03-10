// Events for the AMM

%lang starknet

from starkware.cairo.common.uint256 import Uint256



@event
func TradeOpen(
    caller: felt,
    option_token: felt,
    capital_transfered: Uint256,
    option_tokens_minted: Uint256,
) {
}

@event
func TradeClose(
    caller: felt,
    option_token: felt,
    capital_transfered: Uint256,
    option_tokens_burned: Uint256,
) {
}

@event
func TradeSettle(
    caller: felt,
    option_token: felt,
    capital_transfered: Uint256,
    option_tokens_burned: Uint256,
) {
}

@event
func DepositLiquidity(
    caller: felt,
    lp_token: felt,
    capital_transfered: Uint256,
    lp_tokens_minted: Uint256,
) {
}

@event
func WithdrawLiquidity(
    caller: felt,
    lp_token: felt,
    capital_transfered: Uint256,
    lp_tokens_burned: Uint256,
) {
}

@event
func ExpireOptionTokenForPool(
    lptoken_address: felt,
    option_side: felt,
    strike_price: felt,
    maturity: felt,
) {
}
