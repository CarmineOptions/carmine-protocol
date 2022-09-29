%lang starknet

from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.bool import TRUE, FALSE

from math64x61 import Math64x61

from contracts.constants import EMPIRIC_ORACLE_ADDRESS, EMPIRIC_AGGREGATION_MODE
from contracts.types import Int, Math64x61_
from lib.math_64x61_extended import Math64x61_div_imprecise
from lib.pow import pow10

// List of available tickers:
//  https://docs.empiric.network/using-empiric/supported-assets

// Contract interface copied from docs
@contract_interface
namespace IEmpiricOracle {
    func get_value(key: felt, aggregation_mode: felt) -> (
        value: felt, decimals: felt, last_updated_timestamp: felt, num_sources_aggregated: felt
    ) {
    }
}

// Function to convert base 10**decimals number from oracle to base 2**61
// which is used throughout the AMM
func convert_price{range_check_ptr}(price: felt, decimals: felt) -> (price: felt) {
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

    // FIXME: THIS HAS TO VALIDATED THAT THE ROUNDING CAUSED BY THE IMPRECISE CALCULATIONS IS NOT TOO BIG

    return (res,);
}

@view
func empiric_median_price{syscall_ptr: felt*, range_check_ptr}(key: felt) -> (price: Math64x61_) {
    alloc_locals;

    let (
        value, decimals, last_updated_timestamp, num_sources_aggregated
    ) = IEmpiricOracle.get_value(EMPIRIC_ORACLE_ADDRESS, key, EMPIRIC_AGGREGATION_MODE);

    let (res) = convert_price(value, decimals);

    return (res,);
}


func get_terminal_price{syscall_ptr: felt*, range_check_ptr}(key: felt, maturity: Int) -> (
    price: Math64x61_
) {
    // FIXME: todo
    alloc_locals;

    let res = Math64x61.fromFelt(1500);

    return (res,);
}