%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.main import convert_price

from starkware.cairo.common.pow import pow

from contracts.Math64x61 import Math64x61_fromFelt, Math64x61_div

@external
func test_convert_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (option_size) = Math64x61_fromFelt(100)
    # let (fees) = convert_price(1480230000000000065536, 19)
    let target = 5
    let (x) = Math64x61_fromFelt(10)
    let (fees) = Math64x61_div(option_size, x)

    assert fees = target
    return ()
end

@external
func test_convert_price2{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    # let (option_size) = Math64x61_fromFelt(100)
    alloc_locals

    let (converted_price) = Math64x61_fromFelt(1480230000000)
    let (pow10xM) = pow(10, 9)
    let (pow10x61) = Math64x61_fromFelt(pow10xM)
    let (fin_conv_price) = Math64x61_div(converted_price, pow10x61)
    assert fin_conv_price = 4
    return ()
end
