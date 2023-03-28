%lang starknet

//
// @title Helper module for options pricing
//


from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn_le, assert_nn, assert_not_zero
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_mul,
    uint256_unsigned_div_rem,
    assert_uint256_eq,
    assert_uint256_lt,
)

from math64x61 import Math64x61
from lib.pow import pow10

from contracts.constants import (
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    TRADE_SIDE_SHORT,
    get_decimal,
)
from contracts.types import (Math64x61_, OptionType, OptionSide, Int, Address)


// @notice Selects value based on option type and if call adjusts the value to base tokens
// @dev  Call and Put premia on input are in quote tokens (in USDC in case of ETH/USDC)
//      This function puts them into their respective currency
//      (and selects the premia based on option_type)
//          - call premia into base token (ETH in case of ETH/USDC)
//          - put premia stays the same, ie in quote tokens (USDC in case of ETH/USDC)
// @param call_premia: Call premium
// @param put_premia: Put premium
// @param option_type: Option type - 0 for call and 1 for put
// @param underlying_price: Price of the underlying (spot)
// @return Select either put or call premium and if call adjust by price of underlying
func select_and_adjust_premia{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    call_premia: Math64x61_,
    put_premia: Math64x61_,
    option_type: OptionType,
    underlying_price: Math64x61_
) -> (premia: Math64x61_) {
    // Call and Put premia on input are in quote tokens (in USDC in case of ETH/USDC)
    // This function puts them into their respective currency
    // (and selects the premia based on option_type)
    //  - call premia into base token (ETH in case of ETH/USDC)
    //  - put premia stays the same, ie in quote tokens (USDC in case of ETH/USDC)

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    if (option_type == OPTION_CALL) {
        let adjusted_call_premia = Math64x61.div(call_premia, underlying_price);
        return (premia=adjusted_call_premia);
    }
    return (premia=put_premia);
}


// @notice Converts amount to the currency used by the option
// @dev Amount is in base tokens (in ETH in case of ETH/USDC)
//      This function puts amount into the currency required by given option_type
//          - for call into base token (ETH in case of ETH/USDC)
//          - for put into quote token (USDC in case of ETH/USDC)
// @param amount: Amount to be converted
// @param option_type: Option type - 0 for call and 1 for put
// @param strike_price: Strike price
// @param base_token_address: Address of the base token
// @return Converted amount value
func convert_amount_to_option_currency_from_base_uint256{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    amount: Uint256,
    option_type: OptionType,
    strike_price: Uint256,
    base_token_address: Address,
) -> (converted_amount: Uint256) {
    // Amount is in base tokens (in ETH in case of ETH/USDC)
    // This function puts amount into the currency required by given option_type
    //  - for call into base token (ETH in case of ETH/USDC)
    //  - for put into quote token (USDC in case of ETH/USDC)

    alloc_locals;

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    let sum = amount.low + amount.high;
    assert_nn(sum);
    if (option_type == OPTION_PUT and sum != 0) {
        let (base_token_decimals) = get_decimal(base_token_address);
        let (dec) = pow10(base_token_decimals);
        let dec_ = Uint256(dec, 0);
        let (adjusted_amount_low: Uint256, adjusted_amount_high: Uint256) = uint256_mul(amount, strike_price);
        assert adjusted_amount_high.low = 0;
        assert adjusted_amount_high.high = 0;
        let (quot: Uint256, rem: Uint256) = uint256_unsigned_div_rem(adjusted_amount_low, dec_);
        local quotlow = quot.low;
        with_attr error_message("Option size too low, quot {quotlow}"){
            assert_uint256_lt(Uint256(0,0), quot);
        }
        local remlow = rem.low;
        with_attr error_message("implied rounding, rem {remlow} - please use qauntized amount"){
            assert rem.low = 0;
            assert rem.high = 0;
        }
        return (converted_amount=quot);
    }
    return (converted_amount=amount);
}


// @notice Gets time till maturity in years
// @dev Calculates time till maturity in terms of Math64x61 type
//      Inputted maturity if not in the same type -> has to converted... and it is number
//      of seconds corresponding to unix timestamp
// @param maturity: Maturity as unix timestamp
// @return time till maturity
func get_time_till_maturity{syscall_ptr: felt*, range_check_ptr}(maturity: Int) -> (
    time_till_maturity: Math64x61_
) {
    // Calculates time till maturity in terms of Math64x61 type
    // Inputted maturity if not in the same type -> has to converted... and it is number
    // of seconds corresponding to unix timestamp

    alloc_locals;
    local syscall_ptr: felt* = syscall_ptr;  // Reference revoked fix

    let (currtime) = get_block_timestamp();  // is number of seconds... unix timestamp
    let currtime_math = Math64x61.fromFelt(currtime);
    let maturity_math = Math64x61.fromFelt(maturity);
    //let secs_in_year = Math64x61.fromFelt(60 * 60 * 24 * 365);
    const secs_in_year = 72717065138563052470272000;

    let secs_left = Math64x61.sub(maturity_math, currtime_math);
    with_attr error_message("get_time_till_maturity - time till maturity is negative"){
        assert_nn(secs_left);
    }

    let time_till_maturity = Math64x61.div(secs_left, secs_in_year);
    return (time_till_maturity,);
}


// @notice Adds premium and fees (for long add and for short diff)
// @param side: 0 for long and 1 for short
// @param total_premia_before_fees: premium in Math64x61
// @param total_fees: fees in Math64x61
// @return Premium adjusted for fees
func add_premia_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    side: OptionSide, total_premia_before_fees: Math64x61_, total_fees: Math64x61_
) -> (total_premia: Math64x61_) {
    // Sums fees and premia... in case of long = premia+fees, short = premia-fees

    assert (side - TRADE_SIDE_SHORT) * (side - TRADE_SIDE_LONG) = 0;

    // if side == TRADE_SIDE_LONG (user pays premia) the fees are added on top of premia
    // if side == TRADE_SIDE_SHORT (user receives premia) the fees are subtracted from the premia
    if (side == TRADE_SIDE_LONG) {
        let premia_fees_add = Math64x61.add(total_premia_before_fees, total_fees);
        return (premia_fees_add,);
    }
    let premia_fees_sub = Math64x61.sub(total_premia_before_fees, total_fees);
    return (premia_fees_sub,);
}


// @notice Calculates new volatility and trade volatility
// @param current_volatility: Current volatility in Math64x61
// @param option_size: Option size in Math64x61... for example 1.2 size is represented as 1.2*2**61
// @param option_type: 0 for CALL and 1 for put
// @param side: 0 for LONG and 1 for SHORT
// @param strike_price: strike price in Math64x61
// @param pool_volatility_adjustment_speed: parameter that determines speed of volatility adjustments
// @return New volatility and trade volatility
func get_new_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    current_volatility: Math64x61_,
    option_size: Math64x61_,
    option_type: OptionType,
    side: OptionSide,
    strike_price: Math64x61_,
    pool_volatility_adjustment_speed: Math64x61_,
) -> (new_volatility: Math64x61_, trade_volatility: Math64x61_) {
    // Calculates two volatilities, one for trade that is happening
    // and the other to update the volatility param (storage_var).
    // Docs are here
    // https://carmine-finance.gitbook.io/carmine-options-amm/mechanics-deeper-look/option-pricing-mechanics#volatility-updates

    alloc_locals;

    let (local option_size_in_pool_currency) = _get_option_size_in_pool_currency(
        option_size, option_type, strike_price
    );

    let _relative_option_size = Math64x61.div(option_size_in_pool_currency, pool_volatility_adjustment_speed);
    const hundred = 230584300921369395200; // Math64x61.fromFelt(100);
    local relative_option_size = Math64x61.mul(_relative_option_size, hundred);

    if (side == TRADE_SIDE_LONG) {
        let new_volatility = Math64x61.add(current_volatility, relative_option_size);
    } else {
        let new_volatility = Math64x61.add(current_volatility, -relative_option_size);
    }

    local newvol = new_volatility;
    local _pool_vol_adj_spd = pool_volatility_adjustment_speed;
    with_attr error_message("New volatility in get_new_volatility is negative: new_volatility={newvol}, relative_option_size={relative_option_size}, option_size_in_pool_currency={option_size_in_pool_currency}, pool_vol_adj_spd={_pool_vol_adj_spd}") {
        assert_nn(new_volatility);
    }

    let volsum = Math64x61.add(current_volatility, new_volatility);
    const two = 4611686018427387904;
    let trade_volatility = Math64x61.div(volsum, two);

    return (new_volatility=new_volatility, trade_volatility=trade_volatility);
}


// @notice Converts option size into pool's currency
// @dev for call it does no transform and for put it multiplies the size by strike
// @param option_size: Option size to be converted
// @param option_type: Option type - 0 for call and 1 for put
// @param strike_price: Strike price
// @return Converted size
func _get_option_size_in_pool_currency{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option_size: Math64x61_,
    option_type: OptionType,
    strike_price: Math64x61_
) -> (relative_option_size: Math64x61_) {
    if (option_type == OPTION_CALL) {
        return (option_size,);
    }
    let adjusted_option_size = Math64x61.mul(option_size, strike_price);
    return (adjusted_option_size,);
}
