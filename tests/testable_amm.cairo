# Wrapper for non viewed functions in contracts/option_pricing.cairo
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.amm import do_trade


# wrapper for contracts.option_pricing.d1_d2 for purpose of unit testing
@external
func testable_do_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt,
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    option_size : felt,
) -> (premia: felt):
    let (premia) = do_trade(
        account_id=account_id,
        option_type=option_type,
        strike_price=strike_price,
        maturity=maturity,
        side=side,
        option_size=option_size,
    )
    return (premia=premia)
end
