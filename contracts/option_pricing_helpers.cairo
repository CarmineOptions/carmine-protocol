// Helper function for pricing options

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn_le, assert_nn
from starkware.starknet.common.syscalls import get_block_timestamp
from math64x61 import Math64x61

from contracts.constants import (
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    TRADE_SIDE_SHORT
)
from contracts.types import (Math64x61_, OptionType, OptionSide, Int, Address)


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
    let secs_in_year = Math64x61.fromFelt(60 * 60 * 24 * 365);

    let secs_left = Math64x61.sub(maturity_math, currtime_math);
    assert_nn(secs_left);

    let time_till_maturity = Math64x61.div(secs_left, secs_in_year);
    return (time_till_maturity,);
}


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


func _get_vol_update_denominator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    relative_option_size: Math64x61_, side: OptionSide
) -> (relative_option_size: Math64x61_) {
    if (side == TRADE_SIDE_LONG) {
        let long_denominator = Math64x61.sub(Math64x61.ONE, relative_option_size);
        return (long_denominator,);
    }
    let short_denominator = Math64x61.add(Math64x61.ONE, relative_option_size);
    return (short_denominator,);
}


func get_new_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    current_volatility: Math64x61_,
    option_size: Math64x61_,
    option_type: OptionType,
    side: OptionSide,
    underlying_price: Math64x61_,
    current_pool_balance: felt,
) -> (new_volatility: Math64x61_, trade_volatility: Math64x61_) {
    // Calculates two volatilities, one for trade that is happening
    // and the other to update the volatility param (storage_var).
    // Docs are here
    // https://carmine-finance.gitbook.io/carmine-options-amm/mechanics-deeper-look/option-pricing-mechanics#volatility-updates

    alloc_locals;

    let (option_size_in_pool_currency) = _get_option_size_in_pool_currency(
        option_size, option_type, underlying_price
    );

    let relative_option_size = Math64x61.div(option_size, current_pool_balance);

    // alpha – rate of change assumed to be 1
    let (denominator) = _get_vol_update_denominator(relative_option_size, side);
    let volatility_scale = Math64x61.div(Math64x61.ONE, denominator);
    let new_volatility = Math64x61.mul(current_volatility, volatility_scale);

    let volsum = Math64x61.add(current_volatility, new_volatility);
    let two = Math64x61.fromFelt(2);
    let trade_volatility = Math64x61.div(volsum, two);

    return (new_volatility=new_volatility, trade_volatility=trade_volatility);
}


func _get_option_size_in_pool_currency{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(option_size: felt, option_type: felt, underlying_price: felt) -> (relative_option_size: felt) {
    if (option_type == OPTION_CALL) {
        return (option_size,);
    }
    let adjusted_option_size = Math64x61.mul(option_size, underlying_price);
    return (adjusted_option_size,);
}
