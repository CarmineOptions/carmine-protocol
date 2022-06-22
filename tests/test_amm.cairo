%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.amm import _time_till_maturity

from contracts.Math64x61 import Math64x61_toFelt

@external
func test_sum{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    #local syscall_ptr : felt* = syscall_ptr # Reference revoked fix
    %{ warp(1672527600 - (365*60*60*24)) %}
    let (r_dec) = _time_till_maturity(1672527600)
    let (r_felt) = Math64x61_toFelt(r_dec)
    assert r_felt = 1
    return ()
end
