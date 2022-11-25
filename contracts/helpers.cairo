// Helper functions

%lang starknet

from contracts.constants import (
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    RISK_FREE_RATE,
    get_empiric_key,
    get_opposite_side,
    get_decimal
)
from contracts.fees import get_fees
from contracts.option_pricing import black_scholes
from contracts.oracles import empiric_median_price
from contracts.option_pricing_helpers import (
    select_and_adjust_premia,
    get_time_till_maturity,
    add_premia_fees,
    get_new_volatility
)
from contracts.types import Option, Math64x61_, Address, OptionType, Int

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.math import assert_nn, assert_not_zero, signed_div_rem, assert_le_felt
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le, is_nn
from starkware.cairo.common.uint256 import (
    Uint256,
    assert_le,
    split_64
)
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

from math64x61 import Math64x61
from lib.pow import pow10

func max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value_a: felt, value_b: felt
) -> (max_value: felt) {
    let a_smaller_b = is_le(value_a, value_b);

    if (a_smaller_b == TRUE) {
        return (value_b,);
    }
    return (value_a,);
}

func min{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value_a: felt, value_b: felt
) -> (max_value: felt) {
    let a_smaller_b = is_le(value_a, value_b);

    if (a_smaller_b == TRUE) {
        return (value_a,);
    }
    return (value_b,);
}


func _get_premia_before_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option: Option,
    position_size: Math64x61_,
    option_type: OptionType,
    current_volatility: Math64x61_,
    current_pool_balance: Math64x61_,
) -> (total_premia_before_fees: Int){
    // Gets value of position ADJUSTED for fees!!!

    alloc_locals;

    let side = option.option_side;
    let maturity = option.maturity;
    let strike_price = option.strike_price;
    let quote_token_address = option.quote_token_address;
    let base_token_address = option.base_token_address;
    assert option_type = option.option_type; // TODO remove once tests pass even with this

    let option_size = position_size;

    // 1) Get price of underlying asset
    with_attr error_message("helpers._get_premia_before_fees getting undrelying price FAILED"){
        let (empiric_key) = get_empiric_key(quote_token_address, base_token_address);
        let (underlying_price) = empiric_median_price(empiric_key);
    }

    // 2) Calculate new volatility, calculate trade volatility
    with_attr error_message("helpers._get_premia_before_fees getting volatility FAILED"){
        let (_, trade_volatility) = get_new_volatility(
            current_volatility, option_size, option_type, side, option.strike_price, current_pool_balance
        );
    }

    // 3) Get time till maturity
    with_attr error_message("helpers._get_premia_before_fees getting time_till_maturity FAILED"){
        let (time_till_maturity) = get_time_till_maturity(maturity);
    }

    // 4) risk free rate
    let risk_free_rate_annualized = RISK_FREE_RATE;

    // 5) Get premia
    with_attr error_message("helpers._get_premia_before_fees getting premia FAILED"){
        let HUNDRED = Math64x61.fromFelt(100);
        let sigma = Math64x61.div(trade_volatility, HUNDRED);
        // call_premia, put_premia in quote tokens (USDC in case of ETH/USDC)
        with_attr error_message("black scholes {sigma} {time_till_maturity} {strike_price} {underlying_price}"){
            let (call_premia, put_premia) = black_scholes(
                sigma=sigma,
                time_till_maturity_annualized=time_till_maturity,
                strike_price=strike_price,
                underlying_price=underlying_price,
                risk_free_rate_annualized=risk_free_rate_annualized,
            );
        }
    }
    with_attr error_message("helpers._get_premia_before_fees call/put premia is negative FAILED"){
        assert_nn(call_premia);
        assert_nn(put_premia);
    }

    with_attr error_message("helpers._get_premia_before_fees adjusting premia FAILED"){
        // AFTER THE LINE BELOW, THE PREMIA IS IN TERMS OF CORRESPONDING POOL
        // Ie in case of call option, the premia is in base (ETH in case ETH/USDC)
        // and in quote tokens (USDC in case of ETH/USDC) for put option.
        let (premia) = select_and_adjust_premia(
            call_premia, put_premia, option_type, underlying_price
        );
        // premia adjusted by size (multiplied by size)
        let total_premia_before_fees = Math64x61.mul(premia, option_size);
    }
    with_attr error_message("helpers._get_premia_before_fees premia is negative FAILED"){
        assert_nn(premia);
    }
    with_attr error_message("helpers._get_premia_before_fees total_premia_before_fees is negative FAILED"){
        assert_nn(total_premia_before_fees);
    }

    return (total_premia_before_fees,);
}


func _get_value_of_position{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option: Option,
    position_size: Int,
    option_type: OptionType,
    current_volatility: Math64x61_,
    current_pool_balance: Math64x61_
) -> (position_value: Math64x61_){
    // Gets value of position ADJUSTED for fees!!!

    alloc_locals;

    let side = option.option_side;
    let strike_price = option.strike_price;

    let option_size = position_size;

    let (total_premia_before_fees) = _get_premia_before_fees(
        option=option,
        position_size=position_size,
        option_type=option_type,
        current_volatility=current_volatility,
        current_pool_balance=current_pool_balance
    );

    // Get fees and total premia
    with_attr error_message("helpers._get_value_of_position getting fees FAILED"){
        // fees are already in the currency same as premia
        // Value of position is calculated as "how much remaining value would holder get if liquidated"
        // For long the holder's position is valued as "premia - fees", this is similar to closing
        //      the given position.
        // For short the holder's position is valued as "locked capital - premia - fees" since it would
        //      be the remaining capital if closed position
        let (total_fees) = get_fees(total_premia_before_fees);
        with_attr error_message("helpers._get_value_of_position total_fees is negative FAILED"){
            assert_nn(total_fees);
        }
        let (opposite_side) = get_opposite_side(side);
        let (premia_with_fees) = add_premia_fees(opposite_side, total_premia_before_fees, total_fees);
        with_attr error_message("helpers._get_value_of_position premia_with_fees is negative FAILED"){
            assert_nn(premia_with_fees);
        }
        if (side == TRADE_SIDE_LONG) {
            return (position_value=premia_with_fees);
        }
    }

    if (option_type == OPTION_CALL) {
        let locked_capital = option_size;
        let locked_and_premia_with_fees = Math64x61.sub(locked_capital, premia_with_fees);

        with_attr error_message("helpers._get_value_of_position locked_and_premia_with_fees 1 is negative FAILED"){
            assert_nn(locked_and_premia_with_fees);
        }
        return (position_value = locked_and_premia_with_fees);
    } else {

        let locked_capital = Math64x61.mul(option_size, strike_price);
        let locked_and_premia_with_fees = Math64x61.sub(locked_capital, premia_with_fees);

        with_attr error_message("helpers._get_value_of_position locked_and_premia_with_fees 2 is negative FAILED"){
            assert_nn(locked_and_premia_with_fees);
        }

        return (position_value = locked_and_premia_with_fees);
    }
}


func _get_premia_with_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option: Option,
    position_size: Math64x61_,
    option_type: OptionType,
    current_volatility: Math64x61_,
    current_pool_balance: Math64x61_
) -> (position_value: Math64x61_){
    // Gets premia ADJUSTED for fees!!!
    // FIXME: this is basically the same as _get_value_of_position... only one is from perspective
    // of liquidating position and the other from perspective of entering position

    alloc_locals;

    let side = option.option_side;
    let strike_price = option.strike_price;

    let option_size = position_size;

    let (total_premia_before_fees) = _get_premia_before_fees(
        option=option,
        position_size=position_size,
        option_type=option_type,
        current_volatility=current_volatility,
        current_pool_balance=current_pool_balance
    );

    // Get fees and total premia
    with_attr error_message("helpers._get_premia_with_fees getting fees FAILED"){
        let (total_fees) = get_fees(total_premia_before_fees);
        with_attr error_message("helpers._get_premia_with_fees total_fees is negative FAILED"){
            assert_nn(total_fees);
        }
        let (premia_with_fees) = add_premia_fees(side, total_premia_before_fees, total_fees);
        with_attr error_message("helpers._get_premia_with_fees premia_with_fees is negative FAILED"){
            assert_nn(premia_with_fees);
        }
    }
    return (position_value=premia_with_fees);
}


// Conversions from Math64_61 to Uint256 and back
// Only for balances/token amounts. Takes care of getting decimals etc
func toUint256_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Math64x61_,
    currency_address: Address
) -> Uint256 {
    alloc_locals;

    with_attr error_message("Failed toUint256_balance with input {x}, {currency_address}"){
        // converts 1.2 ETH (as Math64_61 float) to int(1.2*10**18)
        let (decimal) = get_decimal(currency_address);
        let (dec_) = pow10(decimal);
        // with_attr error_message("dec to Math64x61 Failed in toUint256_balance"){
        //     let dec = Math64x61.fromFelt(dec_);
        // }

        // let x_ = Math64x61.mul(x, dec);
        // equivalent opperation as Math64x61.mul, but avoid the scale by 2**61
        // Math64x61.mul takes two Math64x61 and multiplies them and divides them by 2**61
        // (x*2**61) * (y*2**61) / 2**61
        // Instead we skip the "*2**61" near "y" and the "/ 2**61"
        let x_ = x * dec_;

        with_attr error_message("x_ out of bounds in toUint256_balance"){
            assert_le(x, Math64x61.BOUND);
            assert_le(-Math64x61.BOUND, x);
        }

        let amount_felt = Math64x61.toFelt(x_);
        let res = Uint256(low = amount_felt, high = 0);
    }
    return res;
}


func fromUint256_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Uint256,
    currency_address: Address
) -> Math64x61_ {
    alloc_locals;

    let x_low = x.low;
    assert x.high = 0;

    with_attr error_message("Failed fromUint256_balance with input {x_low}, {currency_address}"){
        // converts 1.2*10**18 WEI to 1.2 ETH (to Math64_61 float)
        let (decimal) = get_decimal(currency_address);
        let (dec_) = pow10(decimal);
        // let dec = Math64x61.fromFelt(dec_);

        let x_ = Math64x61.fromUint256(x);
        // let x__ = Math64x61.div(x_, dec);
        // Equivalent to Math64x61.div

        // let div = abs_value(dec_);
        // let div_sign = sign(dec_);
        // no need to get sign of y, sin dec_ is positiove
        // tempvar product = x * FRACT_PART;
        // no need to to do the tempvar, since only x_ is Math64x61 and dec_ is not
        let (x__, _) = signed_div_rem(x_, dec_, Math64x61.BOUND);
        Math64x61.assert64x61(x__);
    }
    return x__;
}


// equivalent to toUint256_balance, but for option_position, which is stored as a felt (Int),
// because we don't need the full range of uint256
func toInt_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Math64x61_,
    currency_address: Address
) -> Int {
    let (decimal) = get_decimal(currency_address);
    let (dec_) = pow10(decimal);
    let x_ = x * dec_;

    with_attr error_message("x_ out of bounds in toUint256_balance"){
        assert_le(x, Math64x61.BOUND);
        assert_le(-Math64x61.BOUND, x);
    }
    let amount_felt = Math64x61.toFelt(x_);

    return amount_felt;
}

func fromInt_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Int,
    currency_address: Address
) -> Math64x61_ {
    let (decimal) = get_decimal(currency_address);
    let (dec_) = pow10(decimal);

    let x_ = Math64x61.fromFelt(x);

    return x_;
}

func intToUint256{bitwise_ptr: BitwiseBuiltin*}(
    x: Int
) -> Uint256 {
    const LOW_BITS = 2 ** 128 - 1; //127 ones. Quite possible there's a off-by-one, watch out
    let (low_part) = bitwise_and(x, LOW_BITS);
    let high_part = x - low_part;
    let res = Uint256(low_part, high_part);
    return res;
}