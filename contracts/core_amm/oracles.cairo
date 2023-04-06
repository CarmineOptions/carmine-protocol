%lang starknet

//
// @title Module with oracle connectors
//

from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem, assert_not_zero
from starkware.cairo.common.bool import TRUE, FALSE

from math64x61 import Math64x61

from constants import EMPIRIC_ORACLE_ADDRESS, EMPIRIC_AGGREGATION_MODE
from types import Int, Math64x61_
from lib.math_64x61_extended import Math64x61_div_imprecise
from lib.pow import pow10


// List of available tickers:
//      https://docs.empiric.network/using-empiric/supported-assets

// Contract interface for Empiric Oracle
@contract_interface
namespace IEmpiricOracle {
    // @notice Gets Empiric's spot median price for given pair_id
    // @param pair_id: Pair_id as per constants.cairo section with EMPIRIC_ETH_USD_KEY and others
    // @return Returns multiple values, median price of the given asset, decimals of given price
    //      value, last timestamp it got updated and number of sources
    func get_spot_median(pair_id: felt) -> (
        price: felt, decimals: felt, last_updated_timestamp: felt, num_sources_aggregated: felt
    ) {
    }
    
    // @notice Gets Empiric's historical price
    // @param key: Key as per constants.cairo section with EMPIRIC_ETH_USD_KEY and others.
    //      Same as pair_id above.
    // @param timestamp: Timestamp for which the price is collected in a way, that the price is 
    //      the last one before the timestamp.
    // @return Returns Checkpoint. Price, Timestamp, aggregation mode and the number of aggregated
    //      resources.
    func get_last_spot_checkpoint_before(key: felt, timestamp: felt) -> (
        checkpoint: Checkpoint, idx: felt
    ) {
    }

}

// Struct for terminal price
struct Checkpoint {
    timestamp: felt,
    value: felt,
    aggregation_mode: felt,
    num_sources_aggregated: felt,
}


// @notice Function to convert base 10**decimals number from oracle to base 2**61 which is used
//      throughout the AMM.
// @dev The toUint256_balance and similar functions are not used, since this is not converting
//      amount of tokens (something with address and decimals).
// @param price: source price. For example 1605.5 in a following form 160550000000
// @param decimals: number of decimals on the price
// @return Returns price in Math64x61 form.
//      For example the 1605.5 in following form 3702030951292585639936.
func convert_price{range_check_ptr}(price: felt, decimals: felt) -> (price: Math64x61_) {
    alloc_locals;

    let is_convertable = is_le(price, Math64x61.INT_PART);
    if (is_convertable == TRUE) {
        let converted_price = Math64x61.fromFelt(price);
        let (pow10xM) = pow10(decimals);
        let pow10xM_to_64x61 = Math64x61.fromFelt(pow10xM);
        let price_64x61 = Math64x61_div_imprecise(converted_price, pow10xM_to_64x61);
        return (price_64x61,);
    }

    let (decimals_1, r) = unsigned_div_rem(decimals, 2);
    let decimals_2 = decimals - decimals_1;

    let (pow_10_m1) = pow10(decimals_1);
    let (c, remainder) = unsigned_div_rem(price, pow_10_m1);

    let (a) = convert_price(c, decimals_2);
    let (b) = convert_price(remainder, decimals);

    let res = Math64x61.add(a, b);

    return (res,);
}


// @notice Wrapper for collection of Empiric's median spot price.
// @dev Fails if the collected price is zero (something completely failed on Empiric's side)
//      but this assert should be redundant ATM.
// @param key: Key as per constants.cairo section with EMPIRIC_ETH_USD_KEY and others.
//      Same as pair_id above.
// @return Returns spot median price in Math64x61 form.
//      For example the 1605.5 in following form 3702030951292585639936.
@view
func empiric_median_price{syscall_ptr: felt*, range_check_ptr}(key: felt) -> (price: Math64x61_) {
    alloc_locals;

    with_attr error_message("Failed when getting median price from Empiric Oracle") {
        let (
            value, decimals, last_updated_timestamp, num_sources_aggregated
        ) = IEmpiricOracle.get_spot_median(EMPIRIC_ORACLE_ADDRESS, key);
    }

    with_attr error_message("Received zero median price from Empiric Oracle") {
        assert_not_zero(value);
    }

    with_attr error_message("Failed when converting Empiric Oracle median price to Math64x61 format") {
        let (res) = convert_price(value, decimals);
        assert_not_zero(res);
    }

    return (res,);
}


// @notice Wrapper for collection of Empiric's historical median price.
// @dev There are few hotfixes for when Empiric was not functioning correctly. These issues have
//      been fixed and we will also be running the Empiric's keeper bots, to make sure
//      the historical data are available.
// @param key: Key as per constants.cairo section with EMPIRIC_ETH_USD_KEY and others.
//      Same as pair_id above.
// @param maturity: Timestamp that is used as cap for the checkpoint collection. Ie the price
//       returned is the last "saved" price just before this timestamp.
// @return Returns last median price before the "maturity" for given asset in a Math64x61 form.
@view
func get_terminal_price{syscall_ptr: felt*, range_check_ptr}(key: felt, maturity: Int) -> (
    price: Math64x61_
){
    alloc_locals;

    with_attr error_message("Failed when getting terminal price from Empiric Oracle") {
        let (last_checkpoint,_) = IEmpiricOracle.get_last_spot_checkpoint_before(
            EMPIRIC_ORACLE_ADDRESS,
            key,
            maturity
        );
    }
    
    with_attr error_message("Received zero terminal price from Empiric Oracle"){
        assert_not_zero(last_checkpoint.value);
    }

    with_attr error_message("Failed when converting Empiric Oracle terminal price to Math64x61 format"){
        // Taken from the Empiric Docs, since Checkpoint does not
        // store this information, SHOULD not change in the future
        let decimals = 8;

        let (res)  = convert_price(
            last_checkpoint.value,
            decimals
        );

        assert_not_zero(res);
    }

    return (res,);
}
