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
from starkware.cairo.common.bool import FALSE


from openzeppelin.token.erc20.IERC20 import IERC20
from math64x61 import Math64x61
from lib.pow import pow10, pow5, pow2


//
// @title Helper Functions Contract
//


// @notice Validates that the deadline has not passed yet
// @dev If the deadline has passed this function will fail the transaction
// @param deadline: Timestamp of the deadline
func check_deadline{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    deadline: felt
) {

    let (current_block_time) = get_block_timestamp();

    with_attr error_message("Transaction is too old") {
        assert_le(current_block_time, deadline);
    }

    return ();
}


// @notice Returns greater of the two values
// @dev If value_a == value_b, returns value_a
// @param value_a: First value
// @param value_b: Second value
// @return max_value: Greater of the two values
func max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value_a: felt, value_b: felt
) -> (max_value: felt) {
    let a_smaller_b = is_le(value_a, value_b);

    if (a_smaller_b == TRUE) {
        return (value_b,);
    }
    return (value_a,);
}


// @notice Returns smaller of the two values
// @dev If value_a == value_b, returns value_b
// @param value_a: First value
// @param value_b: Second value
// @return min_value: Smaller of the two values
func min{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value_a: felt, value_b: felt
) -> (min_value: felt) {
    let a_smaller_b = is_le(value_a, value_b);

    if (a_smaller_b == TRUE) {
        return (value_a,);
    }
    return (value_b,);
}


// @notice Calculates premia without fees, DOES NOT update volatility parameter.
// @dev The above means that this function is called only by view functions and not those allowing
//      actual trading.
// @dev options_size is always denominated in the lowest possible unit of base tokens (ETH in case
//      of ETH/USDC), e.g. wei in case of ETH.
//      Option size of 1 ETH would be 10**18 since 1 ETH = 10**18 wei.
// @param option: Struct containing option data. Look at types.cairo::Option
// @param position_size: Size of the position in Math64x61, which means that size 1.1 is
//      represented as 1.1*2**61.
// @param option_type: Type of the option 0 for Call, 1 for Put
// @param current_volatility: Current volatility of given option.
// @param pool_volatility_adjustment_speed: Determines how fast the volatility would be updated if
//      the position was executed.
// @return total_premia_before_fees: Calculated premia without fees
func _get_premia_before_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option: Option,
    position_size: Math64x61_,
    option_type: OptionType,
    current_volatility: Math64x61_,
    pool_volatility_adjustment_speed: Math64x61_,
) -> (total_premia_before_fees: Math64x61_){

    alloc_locals;

    let side = option.option_side;
    let maturity = option.maturity;
    let strike_price = option.strike_price;
    let quote_token_address = option.quote_token_address;
    let base_token_address = option.base_token_address;

    let option_size = position_size;

    // 1) Get price of underlying asset
    with_attr error_message("helpers._get_premia_before_fees getting undrelying price FAILED"){
        let (empiric_key) = get_empiric_key(quote_token_address, base_token_address);
        let (underlying_price) = empiric_median_price(empiric_key);
    }

    // 2) Calculate new volatility, calculate trade volatility
    with_attr error_message("helpers._get_premia_before_fees getting new volatility FAILED"){
        let (_, trade_volatility) = get_new_volatility(
            current_volatility, option_size, option_type, side, strike_price, pool_volatility_adjustment_speed
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
        const HUNDRED = 230584300921369395200; // Math64x61.fromFelt(100);
        let sigma = Math64x61.div(trade_volatility, HUNDRED);
        // call_premia, put_premia in quote tokens (USDC in case of ETH/USDC)
        with_attr error_message("black scholes time until maturity {time_till_maturity} strike{strike_price} underlying_price{underlying_price} trade volatility{tradevol} current volatility{current_volatility}"){
            let (call_premia, put_premia, is_usable) = black_scholes(
                sigma=sigma,
                time_till_maturity_annualized=time_till_maturity,
                strike_price=strike_price,
                underlying_price=underlying_price,
                risk_free_rate_annualized=risk_free_rate_annualized,
                is_for_trade=0,
            );

            // if (is_usable == FALSE) {
            //     // More readable if they're calculated separately IMHO
            //     // Probably will be changed when optimizing for gas
            //     let price_diff_call = Math64x61.sub(underlying_price, strike_price);
            //     let price_diff_put = Math64x61.sub(strike_price, underlying_price);

            //     let cent = 23058430092136940; // 0.01 * 2**61

            //     let (_call_premia) = max(0, price_diff_call);
            //     let call_premia = Math64x61.add(_call_premia, cent);

            //     let (_put_premia) = max(0, price_diff_put);
            //     let put_premia = Math64x61.add(_put_premia, cent);

            // }
        }
    }

    with_attr error_message("helpers._get_premia_before_fees call/put premia is negative FAILED, call_premia: {call_premia}, put_premia: {put_premia}, sigma: {sigma}, time_till_maturity_annualized: {time_till_maturity}, strike_price: {strike_price}, underlying_price: {underlying_price}, risk_free_rate_annualized: {risk_free_rate_annualized}"){
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

    return (total_premia_before_fees=total_premia_before_fees);
}


// @notice Calculates amount to be paid to buyer and/or seller
// @dev options_size is always denominated in the lowest possible unit of base tokens (ETH in case
//      of ETH/USDC), e.g. wei in case of ETH.
//      Option size of 1 ETH would be 10**18 since 1 ETH = 10**18 wei.
//      Here, however, we use Math64x61, which means that 1 ETH is represented as 1*2**61.
// @param option_type: Type of the option 0 for Call, 1 for Put
// @param option_side: Side of the option 0 for Long, 1 for Short
// @param option_size: Size to be traded, denominated in Math64x61, which means that size 1.1 is
//      represented as 1.1*2**61.
// @param strike_price: Option's strike price in Math64x61.
// @param terminal_price: Price at which option is being settled, in Math64x61.
// @return long_value: Amount to be paid to the buyer
// @return short_value: Amount to be paid to the seller
func split_option_locked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: OptionType,
    option_side: OptionSide,
    option_size: Math64x61_,
    strike_price: Math64x61_,
    terminal_price: Math64x61_,
) -> (long_value: Math64x61_, short_value: Math64x61_) {
    alloc_locals;

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    if (option_type == OPTION_CALL) {
        // User receives option_size * max(0,  (terminal_price - strike_price) / terminal_price) in base token for long
        // User receives option_size * (1 - max(0,  (terminal_price - strike_price) / terminal_price)) for short
        // Summing the two equals option_size
        // In reality there is rounding that is happening and since we are not able to distribute
        // tokens to buyers and sellers all at the same transaction and since users can split
        // tokens we have to do it like this to ensure that
        // locked capital >= to_be_paid_buyer + to_be_paid_seller
        // and the equality cannot be guaranteed because of the reasons above
        let price_diff = Math64x61.sub(terminal_price, strike_price);
        let price_relative_diff = Math64x61.div(price_diff, terminal_price);
        let (buyer_relative_profit) = max(0, price_relative_diff);
        let one = Math64x61.fromFelt(1);
        let seller_relative_profit = Math64x61.sub(one, buyer_relative_profit);

        let to_be_paid_buyer = Math64x61.mul(option_size, buyer_relative_profit);
        let to_be_paid_seller = Math64x61.mul(option_size, seller_relative_profit);

        return (to_be_paid_buyer, to_be_paid_seller);
    }

    // For Put option
    // User receives option_size * max(0, (strike_price - terminal_price)) in base token for long
    // User receives option_size * min(strike_price, terminal_price) for short
    // Summing the two equals option_size * strike_price (=locked capital
    let price_diff = Math64x61.sub(strike_price, terminal_price);
    let (buyer_relative_profit) = max(0, price_diff);
    let (seller_relative_profit) = min(strike_price, terminal_price);

    let to_be_paid_buyer = Math64x61.mul(option_size, buyer_relative_profit);
    let to_be_paid_seller = Math64x61.mul(option_size, seller_relative_profit);

    return (to_be_paid_buyer, to_be_paid_seller);
}


// @notice Calculates the value of the provided position adjusted for fees
// @dev options_size is always denominated in the lowest possible unit of base tokens (ETH in case
//      of ETH/USDC), e.g. wei in case of ETH.
// @dev Option size of 1 ETH would be 10**18 since 1 ETH = 10**18 wei.
// @param option: Struct containing option data. Look at types.cairo::Option
// @param position_size: Size of the position, denominated in Math64x61, which means that size 1.1
//      is represented as 1.1*2**61.
// @param option_type: Type of the option 0 for Call, 1 for Put
// @param current_volatility: Current volatility of the AMM, in Math64x61.
// @param pool_volatility_adjustment_speed: Determines how much the volatility will change
// @return position_value: Value of the provided position adjusted for fees
func _get_value_of_position{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option: Option,
    position_size: Int,
    option_type: OptionType,
    current_volatility: Math64x61_,
    pool_volatility_adjustment_speed: Math64x61_
) -> (position_value: Math64x61_){
    alloc_locals;

    // If the value of expired has to be calculated use the below
    with_attr error_message("helpers._get_value_of_position failed on initial statements") {
        let (current_block_time) = get_block_timestamp();
        let maturity = option.maturity;
        let is_ripe = is_le(maturity, current_block_time);
    }
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

    with_attr error_message("helpers._get_value_of_position failed on getting option size") {
        let side = option.option_side;
        let strike_price = option.strike_price;

        let option_size_m64x61 = fromInt_balance(
            x=position_size,
            currency_address=option.base_token_address
        );
    }


    with_attr error_message("helpers._get_value_of_position failed on getting premium") {
        let (total_premia_before_fees) = _get_premia_before_fees(
            option=option,
            position_size=option_size_m64x61,
            option_type=option_type,
            current_volatility=current_volatility,
            pool_volatility_adjustment_speed=pool_volatility_adjustment_speed
        );
    }
    // if (is_extremely_high == TRUE) {
    //     if option.option_side == long
    //         total_premia_before_fees = 0.01
    //     else:
    //         total_premia_before_fees = 0

    //     underlying_price >> strike
    //         if option.option_side == long
    //             total_premia_before_fees = underlying - strike + 0.01
    //         else:
    //             total_premia_before_fees = underlying - strike
    // }

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

        with_attr error_message("helpers._get_value_of_position failed on last calculation 1") {
            let locked_and_premia_with_fees = Math64x61.sub(option_size_m64x61, premia_with_fees);
        }

        with_attr error_message("helpers._get_value_of_position locked_and_premia_with_fees 1 is negative FAILED"){
            assert_nn(locked_and_premia_with_fees);
        }
        return (position_value = locked_and_premia_with_fees);
    } else {

        with_attr error_message("helpers._get_value_of_position failed on last calculation 2") {
            let locked_capital = Math64x61.mul(option_size_m64x61, strike_price);
            let locked_and_premia_with_fees = Math64x61.sub(locked_capital, premia_with_fees);
        }

        with_attr error_message("helpers._get_value_of_position locked_and_premia_with_fees 2 is negative FAILED"){
            assert_nn(locked_and_premia_with_fees);
        }

        return (position_value = locked_and_premia_with_fees);
    }
}


// @notice Calculates the premia for the provided position adjusted for fees
// @dev options_size is always denominated in the lowest possible unit of base tokens (ETH in case
//      of ETH/USDC), e.g. wei in case of ETH.
// @dev Option size of 1 ETH would be 10**18 since 1 ETH = 10**18 wei.
// @param option: Struct containing option data. Look at types.cairo::Option
// @param position_size: Size of the position, denominated in Math64x61, which means that size 1.1
//      is represented as 1.1*2**61.
// @param option_type: Type of the option 0 for Call, 1 for Put
// @param current_volatility: Current volatility of the AMM, in Math64x61.
// @param pool_volatility_adjustment_speed: Determines how much the volatility will change
// @return premia_with_fees: Premia with fees for the provided position
func _get_premia_with_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option: Option,
    position_size: Math64x61_,
    option_type: OptionType,
    current_volatility: Math64x61_,
    pool_volatility_adjustment_speed: Math64x61_
) -> (premia_with_fees: Math64x61_){
    // FIXME: this is basically the same as _get_value_of_position... only one is from perspective
    // of liquidating position and the other from perspective of entering position... so consider
    // joining these together

    alloc_locals;

    let side = option.option_side;
    let strike_price = option.strike_price;

    let option_size = position_size;

    let (total_premia_before_fees) = _get_premia_before_fees(
        option=option,
        position_size=position_size,
        option_type=option_type,
        current_volatility=current_volatility,
        pool_volatility_adjustment_speed=pool_volatility_adjustment_speed
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
    return (premia_with_fees=premia_with_fees);
}


// @notice Converts the value into Uint256 balance
// @dev Conversions from Math64_61 to Uint256
// @dev Only for balances/token amounts, takes care of getting decimals etc
// @dev This function was done in several steps to optimize this in terms precision. It's pretty
//      nasty in terms of deconstruction. I would suggest checking tests, it might be faster.
// @param x: Value to be converted
// @param currency_address: Address of the currency - used to get decimals
// @return Input converted to Uint256
func toUint256_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Math64x61_,
    currency_address: Address
) -> Uint256 {
    // converts for example 1.2 ETH (as Math64_61 float) to int(1.2*10**18)

    // We will guide you through with an example
    // x = 1.2 * 2**61 (example input... 2**61 since it is Math64x61)
    // We want to divide the number by 2**61 and multiply by 10**18 to get number in the "wei style
    // But the order is important, first multiply and then divide, otherwise the .2 would be lost.
    // (1.2 * 2**61) * 10**18 / 2**61
    // We can split the 10*18 to (2**18 * 5**18)
    // (1.2 * 2**61) * 2**18 * 5**18 / 2**61

    alloc_locals;

    with_attr error_message("Failed toUint256_balance with input {x}, {currency_address}"){
        let (decimal) = get_decimal(currency_address);
        let (five_to_dec) = pow5(decimal);
        // rearange a little 
        // (1.2 * 2**61 * 5**18) * 2**18 / 2**61
        // (x_5) * 2**18 / 2**61
        let x_5 = x * five_to_dec;

        // check for overflows
        with_attr error_message("x_5 out of bounds in toUint256_balance"){
            assert_le(x_5, Math64x61.BOUND);
            assert_nn(x_5);
        }

        // we can rearange a little again
        // (1.2 * 2**61 * 5**18) / (2**61 / 2**18)
        // (1.2 * 2**61 * 5**18) / 2**(61 - 18)
        let sixty_one_minus_dec = 61 - decimal;
        assert_nn(sixty_one_minus_dec);
        let (decreased_FRACT_PART) = pow2(sixty_one_minus_dec);
        // just to see where we are
        // (x_5) / decreased_FRACT_PART
        let (amount_felt, _) = signed_div_rem(x_5, decreased_FRACT_PART, Math64x61.BOUND);

        let res = Uint256(low = amount_felt, high = 0);
    }

    return res;
}


// @notice Converts the value from Uint256 balance to Math64_61
// @dev Conversions from Uint256 to Math64_61
// @dev Only for balances/token amounts, takes care of getting decimals etc
// @param x: Value to be converted
// @param currency_address: Address of the currency - used to get decimals
// @return Input converted to Math64_61
func fromUint256_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Uint256,
    currency_address: Address
) -> Math64x61_ {
    // converts for example 1.2*10**18 wei to 1.2*2**61 (Math64x61).

    // We will guide you through with an example
    // x = 1.2*10**18 (example input... 10**18 since it is ETH)
    // We want to divide the number by 10**18 and multiply by 2**61 to get Math64x61 number
    // But the order is important, first multiply and then divide, otherwise the .2 would be lost.
    // (1.2 * 10**18) * 2**61 / 10**18
    // We can split the 10*18 to (2**18 * 5**18)
    // (1.2 * 10**18) * 2**61 / (5**18 * 2**18)

    alloc_locals;

    local x_low = x.low;
    with_attr error_message("Failed fromUint256_balance with input {x_low}, {currency_address}"){
        let (decimal) = get_decimal(currency_address);
        let (five_to_dec) = pow5(decimal);

        assert x.high = 0;
        let x_low = x.low;

        // Increase the bound of original Math64x61.INT_PART check
        // We can do this, because below the multiplication "let x_ = x_low * decreased_FRACT_PART"
        // is done on decrease Math64x61.FRACT_PART
        // so the total does not go above 2**125
        let sixty_four_plus_dec = 64 + decimal;
        assert_nn(sixty_four_plus_dec);
        let (increased_INT_PART) = pow2(sixty_four_plus_dec);
        assert_le(x_low, increased_INT_PART);
        assert_le(-increased_INT_PART, x_low);

        // (1.2 * 10**18) * 2**61 / (5**18 * 2**18)
        // so we have
        // x * 2**61 / (five_to_dec * 2**18)
        // and with a little bit of rearanging
        // (1.2 * 10**18) / 5**18 * (2**61 / 2**18)
        // (1.2 * 10**18) / 5**18 * 2**(61-18)
        // x / five_to_dec * 2**(sixty_one_minus_dec)
        let sixty_one_minus_dec = 61 - decimal;
        assert_nn(sixty_one_minus_dec);
        let (decreased_FRACT_PART) = pow2(sixty_one_minus_dec);
        // x / five_to_dec * decreased_FRACT_PART
        // x * decreased_FRACT_PART / five_to_dec
        let x_ = x_low * decreased_FRACT_PART;
        // x_ / five_to_dec
        let (x__, _) = unsigned_div_rem(x_, five_to_dec);
        // Just checking the final number is not out of bounds.
        Math64x61.assert64x61(x__);
    }
    return x__;
}


// @notice Converts the value from Math64_61 balance to Int (felt)
// @dev Same as toUint256_balance, used when Uint256 range is not needed
// @param x: Value to be converted
// @param currency_address: Address of the currency - used to get decimals
// @return Input converted to Int (felt)
func toInt_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Math64x61_,
    currency_address: Address
) -> Int {
    alloc_locals;

    let uint256 = toUint256_balance(x, currency_address);
    assert uint256.high = 0;
    let low128 = uint256.low;

    return low128;
}


// @notice Converts the value from Int (felt) balance to Math64_61
// @dev Basically just a wrapper around fromUint256_balance for different input.
// @param x: Value to be converted
// @param currency_address: Address of the currency - used to get decimals
// @return Input converted to Math64_61
func fromInt_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Int,
    currency_address: Address
) -> Math64x61_ {
    alloc_locals;

    assert_nn(x);
    let uint256 = Uint256(low=x, high=0);
    with_attr error_message("Failed fromInt_balance with input {x}, {currency_address}"){
        let math64_61 = fromUint256_balance(uint256, currency_address);
    }
    return math64_61;
}


// @notice Converts the value from Int (felt) to Uint256
// @dev Fails if value too big, otherwise returns { low: value, high: 0 }
// @param x: Value to be converted
// @return Value as Uint256
func intToUint256{range_check_ptr}(
    x: Int
) -> Uint256 {
    assert_nn(x);
    with_attr error_message("Unable to work with x this big until Cairo 1.0 comes along") {
        assert_le_felt(x, 2**127-1);
        let res = Uint256(x, 0);
    }
    return res;
}


// @notice Returns address of the underlying asset based on the option's data
// @param option_type: Type of the option 0 for Call, 1 for Put
// @param base_token_address: Address of the base token (ETH in ETH/USDC)
// @param quote_token_address: Address of the quote token (USDC in ETH/USDC)
// @return Address of the underlying asset
func get_underlying_from_option_data(option_type: OptionType, base_token_address: Address, quote_token_address: Address) -> Address {
    if (option_type == OPTION_CALL) {
        return base_token_address;
    } else {
        return quote_token_address;
    }
}
