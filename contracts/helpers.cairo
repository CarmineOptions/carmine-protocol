// Helper functions

%lang starknet

from contracts.constants import (
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    RISK_FREE_RATE,
    STOP_TRADING_BEFORE_MATURITY_SECONDS,
    get_empiric_key,
    get_opposite_side,
    get_decimal
)
from contracts.fees import get_fees
from contracts.option_pricing import black_scholes
from contracts.oracles import empiric_median_price, get_terminal_price
from contracts.option_pricing_helpers import (
    select_and_adjust_premia,
    get_time_till_maturity,
    add_premia_fees,
    get_new_volatility
)

from contracts.types import Option, Math64x61_, Address, OptionType, Int, OptionSide


from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.math import assert_nn, assert_not_zero, unsigned_div_rem, signed_div_rem, assert_le_felt, assert_le
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le, is_nn
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.bitwise import bitwise_and
from starkware.starknet.common.syscalls import get_block_timestamp


from openzeppelin.token.erc20.IERC20 import IERC20
from math64x61 import Math64x61
from lib.pow import pow10, pow5, pow2



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
<<<<<<< HEAD
    position_size: Math64x61_,
    option_type: OptionType,
    current_volatility: Math64x61_,
    current_pool_balance: Math64x61_,
) -> (total_premia_before_fees: Math64x61_){
||||||| parent of 689e4cc (Polish replace felt with specific types)
    position_size: felt,
    option_type: felt,
    current_volatility: felt,
    current_pool_balance: felt
) -> (total_premia_before_fees: felt){
=======
    position_size: Math64x61_,
    option_type: OptionType,
    current_volatility: Math64x61_,
    current_pool_balance: Math64x61_
) -> (total_premia_before_fees: Math64x61_){
>>>>>>> 689e4cc (Polish replace felt with specific types)
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
            current_volatility, option_size, option_type, side, strike_price, current_pool_balance
        );
        local tradevol = trade_volatility;
    }

    // 3) Get time till maturity
    with_attr error_message("helpers._get_premia_before_fees getting time_till_maturity FAILED"){
        let (ttm) = get_time_till_maturity(maturity);
        local time_till_maturity = ttm;
    }

    // 4) risk free rate
    let risk_free_rate_annualized = RISK_FREE_RATE;

    // 5) Get premia
    with_attr error_message("helpers._get_premia_before_fees getting premia FAILED"){
        let HUNDRED = Math64x61.fromFelt(100);
        let sigma = Math64x61.div(trade_volatility, HUNDRED);
        // call_premia, put_premia in quote tokens (USDC in case of ETH/USDC)
        with_attr error_message("black scholes time until maturity{time_till_maturity} strike{strike_price} underlying_price{underlying_price} trade volatility{tradevol} current volatility{current_volatility} current pool balance{current_pool_balance}"){
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


func split_option_locked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: OptionType,
    option_side: OptionSide,
    option_size: Math64x61_,
    strike_price: Math64x61_,
    terminal_price: Math64x61_, // terminal price is price at which option is being settled
) -> (long_value: Math64x61_, short_value: Math64x61_) {
    alloc_locals;

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    if (option_type == OPTION_CALL) {
        // User receives max(0, option_size * (terminal_price - strike_price) / terminal_price) in base token for long
        // User receives (option_size - long_profit) for short
        let price_diff = Math64x61.sub(terminal_price, strike_price);
        let to_be_paid_quote = Math64x61.mul(option_size, price_diff);
        let to_be_paid_base = Math64x61.div(to_be_paid_quote, terminal_price);
        let (to_be_paid_buyer) = max(0, to_be_paid_base);

        let to_be_paid_seller = Math64x61.sub(option_size, to_be_paid_buyer);

        return (to_be_paid_buyer, to_be_paid_seller);
    }

    // For Put option
    // User receives  max(0, option_size * (strike_price - terminal_price)) in base token for long
    // User receives (option_size * strike_price - long_profit) for short
    let price_diff = Math64x61.sub(strike_price, terminal_price);
    let amount_x_diff_quote = Math64x61.mul(option_size, price_diff);
    let (to_be_paid_buyer) = max(0, amount_x_diff_quote);
    let to_be_paid_seller_ = Math64x61.mul(option_size, strike_price);
    let to_be_paid_seller = Math64x61.sub(to_be_paid_seller_, to_be_paid_buyer);

    return (to_be_paid_buyer, to_be_paid_seller);
}


func _get_value_of_position{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option: Option,
<<<<<<< HEAD
    position_size: Int,
    option_type: OptionType,
    current_volatility: Math64x61_,
    current_pool_balance: Math64x61_
) -> (position_value: Math64x61_){
||||||| parent of 689e4cc (Polish replace felt with specific types)
    position_size: felt,
    option_type: felt,
    current_volatility: felt,
    current_pool_balance: felt
) -> (position_value: felt){
=======
    position_size: Math64x61_,
    option_type: OptionType,
    current_volatility: Math64x61_,
    current_pool_balance: Math64x61_
) -> (position_value: Math64x61_){
>>>>>>> 689e4cc (Polish replace felt with specific types)
    // Gets value of position ADJUSTED for fees!!!

    alloc_locals;

    // If the value of expired has to be calculated use the below
    let (current_block_time) = get_block_timestamp();
    let maturity = option.maturity;
    let is_ripe = is_le(maturity, current_block_time);
    with_attr error_message("helpers._get_value_of_position failed on ripe option: maturity: {maturity}, current_block_time: {current_block_time}") {
        if (is_ripe == TRUE) {
            let quote_token_address = option.quote_token_address;
            let base_token_address = option.base_token_address;
            let (empiric_key) = get_empiric_key(quote_token_address, base_token_address);
            let (terminal_price: Math64x61_) = get_terminal_price(empiric_key, option.maturity);

            let (long_value, short_value) = split_option_locked_capital(
                option.option_type, option.option_side, position_size, option.strike_price, terminal_price
            );
            if (option.option_side == TRADE_SIDE_LONG) {
                return (long_value,);
            }
            return (short_value,);
        }
    }

    // Fail if the value of option that matures in 2 hours or less (can't price the option)
    with_attr error_message("Unable to calculate position value, please wait till option with maturity {maturity} expires.") {
        assert_le(current_block_time, maturity - STOP_TRADING_BEFORE_MATURITY_SECONDS);
    }

    let side = option.option_side;
    let strike_price = option.strike_price;

    let option_size_m64x61_ = Math64x61.fromFelt(position_size);
    let (base_decimals: felt) = IERC20.decimals(contract_address=option.base_token_address);
    let (base_div) = pow10(base_decimals);
    let base_div_m64x61 = Math64x61.fromFelt(base_div);
    let option_size_m64x61 = Math64x61.div(option_size_m64x61_, base_div_m64x61);

    let (total_premia_before_fees) = _get_premia_before_fees(
        option=option,
        position_size=option_size_m64x61,
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
        let locked_and_premia_with_fees = Math64x61.sub(option_size_m64x61, premia_with_fees);

        with_attr error_message("helpers._get_value_of_position locked_and_premia_with_fees 1 is negative FAILED"){
            assert_nn(locked_and_premia_with_fees);
        }
        return (position_value = locked_and_premia_with_fees);
    } else {

        let locked_capital = Math64x61.mul(option_size_m64x61, strike_price);
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
        // let (dec_) = pow10(decimal);
        let (five_to_dec) = pow5(decimal);
        // with_attr error_message("dec to Math64x61 Failed in toUint256_balance"){
        //     let dec = Math64x61.fromFelt(dec_);
        // }

        // let x_ = Math64x61.mul(x, dec);
        // equivalent opperation as Math64x61.mul, but avoid the scale by 2**61
        // Math64x61.mul takes two Math64x61 and multiplies them and divides them by 2**61
        // (x*2**61) * (y*2**61) / 2**61
        // Instead we skip the "*2**61" near "y" and the "/ 2**61"
        // let x_ = x * dec_;
        let x_5 = x * five_to_dec;

        with_attr error_message("x_5 out of bounds in toUint256_balance"){
            assert_le(x_5, Math64x61.BOUND);
            assert_nn(x_5);
        }

        // To convert x_ to felt we could do the line below (x_ is commented)
        // let amount_felt = Math64x61.toFelt(x_);
        // or we could call directly what the toFelt does "signed_div_rem(x, FRACT_PART, BOUND);"
        // since x_ is just x * dec_ = x * 10**decimal = x * 2**decimal * 5**decimal
        // we can calculate x_5 = x * 5**decimal
        // and then divide by 2**(61-decimal) instead of Math64x61.FRACT_PART of the original number
        let sixty_one_minus_dec = 61 - decimal;
        let (decreased_FRACT_PART) = pow2(sixty_one_minus_dec);
        let (amount_felt, _) = signed_div_rem(x_5, decreased_FRACT_PART, Math64x61.BOUND);

        let res = Uint256(low = amount_felt, high = 0);
    }

    return res;
}


func fromUint256_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Uint256,
    currency_address: Address
) -> Math64x61_ {
    alloc_locals;

    local x_low = x.low;
    with_attr error_message("Failed fromUint256_balance with input {x_low}, {currency_address}"){
        // converts 1.2*10**18 WEI to 1.2 ETH (to Math64_61 float)
        let (decimal) = get_decimal(currency_address);
        // let (dec_) = pow10(decimal);
        let (five_to_dec) = pow5(decimal);
        // let dec = Math64x61.fromFelt(dec_);

        // let x_ = Math64x61.fromUint256(x);
        // "Math64x61.fromUint256" is just fromFelt(x.low)
        // "Math64x61.fromFelt(x.low)" multiplies the number by Math64x61.FRACT_PART (2 ** 61)
        // and checks that x.low is within Math64x61.INT_PART
        assert x.high = 0;
        let x_low = x.low;

        // Increase the bound of original Math64x61.INT_PART check
        // We can do this, because below the multiplication "let x_ = x_low * decreased_FRACT_PART"
        // is done on decrease Math64x61.FRACT_PART
        // so the total does not go above 2**125
        let sixty_four_plus_dec = 64 + decimal;
        let (increased_INT_PART) = pow2(sixty_four_plus_dec);
        assert_le(x_low, increased_INT_PART);
        assert_le(-increased_INT_PART, x_low);

        let sixty_one_minus_dec = 61 - decimal;
        let (decreased_FRACT_PART) = pow2(sixty_one_minus_dec);
        let x_ = x_low * decreased_FRACT_PART;

        // let x__ = Math64x61.div(x_, dec);
        // Equivalent to Math64x61.div

        // let div = abs_value(dec_);
        // let div_sign = sign(dec_);
        // no need to get sign of y, sin dec_ is positiove
        // tempvar product = x * FRACT_PART;
        // no need to to do the tempvar, since only x_ is Math64x61 and dec_ is not
        let (x__, _) = unsigned_div_rem(x_, five_to_dec);
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

    with_attr error_message("x_ out of bounds in toInt_balance"){
        assert_le(x_, Math64x61.BOUND);
        assert_nn(x_);
    }
    let amount_felt = Math64x61.toFelt(x_);
    assert_nn(amount_felt);

    return amount_felt;
}


func fromInt_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Int,
    currency_address: Address
) -> Math64x61_ {
    assert_nn(x);
    let (decimal) = get_decimal(currency_address);
    let (dec_) = pow10(decimal);

    with_attr error_message("unable to convert {x} to math64x61 number"){
        let x_ = Math64x61.fromFelt(x);
        with_attr error_message("fromInt_balance failed unsigned_div_rem( {dec_} {x_} )") {
            let (x__, _) = unsigned_div_rem(x_, dec_);
        }
        Math64x61.assert64x61(x__);
    }
    return x__;
}


func intToUint256{range_check_ptr}(
    x: Int
) -> Uint256 {
    with_attr error_message("Unable to work with x this big until Cairo 1.0 comes along") {
        assert_le_felt(x, 2**127-1);
        let res = Uint256(x, 0);
    }
//    const LOW_BITS = 2 ** 128 - 1; //127 ones. Quite possible there's a off-by-one, watch out
//    let (low_part) = bitwise_and(x, LOW_BITS);
//    let high_part = x - low_part;
//    let res = Uint256(low_part, high_part);
    return res;
}


func get_underlying_from_option_data(option_type: OptionType, base_token_address: Address, quote_token_address: Address) -> Address {
    if (option_type == OPTION_CALL) {
        return base_token_address;
    } else {
        return quote_token_address;
    }
}
