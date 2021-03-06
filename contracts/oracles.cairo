%lang starknet

from starkware.cairo.common.pow import pow
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.bool import TRUE, FALSE

from contracts.Math64x61 import (
    Math64x61_fromFelt,
    Math64x61_div,
    Math64x61_INT_PART,
    Math64x61_add,
    Math64x61_sqrt,
)

from contracts._cfg import EMPIRIC_ORACLE_ADDRESS, EMPIRIC_AGGREGATION_MODE
from lib.math_64x61_extended import Math64x61_div_imprecise

# List of available tickers:
#  https://docs.empiric.network/using-empiric/supported-assets

# Contract interface copied from docs
@contract_interface
namespace IEmpiricOracle:
    func get_value(key : felt, aggregation_mode : felt) -> (
        value : felt, decimals : felt, last_updated_timestamp : felt, num_sources_aggregated : felt
    ):
    end
end

# Function to convert base 10**decimals number from oracle to base 2**61
# which is used throughout the AMM
func convert_price{range_check_ptr}(price : felt, decimals : felt) -> (price : felt):
    alloc_locals

    let (is_convertable) = is_le(price, Math64x61_INT_PART)
    if is_convertable == TRUE:
        let (converted_price) = Math64x61_fromFelt(price)
        let (pow10xM) = pow(10, decimals)
        let (pow10xM_to_64x61) = Math64x61_fromFelt(pow10xM)
        let (price_64x61) = Math64x61_div_imprecise(converted_price, pow10xM_to_64x61)
        return (price_64x61)
    end

    let (decimals_1, r) = unsigned_div_rem(decimals, 2)
    let decimals_2 = decimals - decimals_1

    let (pow_10_m1) = pow(10, decimals_1)
    let (c, remainder) = unsigned_div_rem(price, pow_10_m1)

    let (a) = convert_price(c, decimals_2)
    let (b) = convert_price(remainder, decimals)

    let (res) = Math64x61_add(a, b)

    # FIXME: THIS HAS TO VALIDATED THAT THE ROUNDING CAUSED BY THE IMPRECISE CALCULATIONS IS NOT TOO BIG

    return (res)
end

@view
func empiric_median_price{syscall_ptr : felt*, range_check_ptr}(key : felt) -> (price : felt):
    alloc_locals

    let (
        value, decimals, last_updated_timestamp, num_sources_aggregated
    ) = IEmpiricOracle.get_value(EMPIRIC_ORACLE_ADDRESS, key, EMPIRIC_AGGREGATION_MODE)

    let (res) = convert_price(value, decimals)

    return (res)
end
