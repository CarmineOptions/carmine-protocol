%lang starknet

from starkware.cairo.common.pow import pow
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_le, unsigned_div_rem
from starkware.cairo.common.bool import TRUE

from contracts.Math64x61 import (
    Math64x61_fromFelt,
    Math64x61_div,
    Math64x61_fromUint256,
    Math64x61_toFelt,
    Math64x61_INT_PART,
    Math64x61_add,
)

from src._cfg import EMPIRIC_ORACLE_ADDRESS, EMPIRIC_AGGREGATION_MODE

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

func convert_price{range_check_ptr}(price : felt, m : felt) -> (price : felt):
    alloc_locals

    let (is_convertable) = is_le(price, Math64x61_INT_PART)
    if is_convertable == 1:
        assert_le(price, Math64x61_INT_PART)
        let (converted_price) = Math64x61_fromFelt(price)
        let (pow10xM) = pow(10, m)
        let (pow10x61) = Math64x61_fromFelt(pow10xM)
        let (fin_conv_price) = Math64x61_div(converted_price, pow10x61)

        return (fin_conv_price)
    end

    let (m_1, r) = unsigned_div_rem(m, 2)
    let m_2 = m - m_1

    let (p10) = pow(10, m_1)
    let (c, b_tmp2) = unsigned_div_rem(price, p10)
    let (a) = convert_price(c, m_2)

    # let b_tmp2 = price - c
    let (b) = convert_price(b_tmp2, m)

    let (res) = Math64x61_add(a, b)
    # let (pow10x18) = pow(10, 18)
    # let (fin_res) = Math64x61_div(res, pow10x18)

    return (res)
end

# decimals = 9
# m_1 = 4
# m_2 = 5
# 150_000_000_100 / 10**4 = 15_000_000... ma new decimals = decimals-m_1
# 150_000_000_100 - 10**4 * 15_000_000 = 100... ma puvodni decimals
# x = MathFromFelt(15_000_000) / MathFromFelt(10**(decimals-m_1)) = 15.00000000
# y = MathFromFelt(100) / MathFromFelt(10**(decimals)) = 0.00...000100

@view
func get_median_price{syscall_ptr : felt*, range_check_ptr}(key : felt, num : felt) -> (
    price : felt
):
    alloc_locals

    let (
        value, decimals, last_updated_timestamp, num_sources_aggregated
    ) = IEmpiricOracle.get_value(EMPIRIC_ORACLE_ADDRESS, key, EMPIRIC_AGGREGATION_MODE)

    # let value = 1574120000000000000000

    # let (sth) = convert_price(value, num)

    return (value)
end

# original_oracle_price =...
# m = rozumna vec, ktera rozdeli cenu
# part_a = original_oracle_price / 10**(m)
# part_b = original_oracle_price - part_a * 10**(m)
# part_a_math = MathFromFelt(part_a)
# part_b_math = MathFromFelt(part_b)
# converted_oracle_price = MathDiv(part_a_math, 10**(18-m)) + MathDiv(part_b_math, 10**18)

# func convert_price{range_check_ptr}(original_price : felt, decimals : felt) -> (
#     converted_price : felt
# ):
#     alloc_locals

# let m = 2
#     let (sth3) = pow(10, decimals)

# let (sth) = pow(10, m)
#     let part_a = original_price / sth

# let (sth2) = pow(10, decimals - m)
#     let (part_a_math) = Math64x61_fromFelt(part_a)
#     let (a) = Math64x61_div(part_a_math, sth2)

# let part_b = original_price - part_a * sth
#     let (part_b_math) = Math64x61_fromFelt(part_b)

# let (b) = Math64x61_div(part_b_math, sth3)

# let converted_price = a - b

# return (converted_price=converted_price)
# end

# def convert_price(original_price, m):
#    if original_price is convertable to math6461:
#       converted_price =...
#       return converted price
#    m_1 = m / 2
#    m_2 = m - m_1
#    return convert_price(original_price / m_1, m_1) + convert_price(original_price - original_price / m_1, m)

# Function to collect median price of selected asset

# func reduce_dec(price : felt, decimals : felt) -> (price : felt):
#     # if decimals == 16:
#     #     return (price=price)
#     # end

# let tmp = price / 10

# # let (res) = reduce_dec(tmp, decimals - 1)

# return (tmp)
# end
