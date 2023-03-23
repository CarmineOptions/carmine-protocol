// Wrapper for non viewed functions in contracts/option_pricing.cairo
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.option_pricing import std_normal_cdf, d1_d2, black_scholes



@external
func test_black_scholes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) {
    // FIXME: move the test_option_pricing.py here

    let (call_premia, put_premia, _) = black_scholes(
        sigma=23058430092136940,
        time_till_maturity_annualized=230584300921369408,
        strike_price=230584300921369395200,
        underlying_price=230584300921369395200,
        risk_free_rate_annualized=69175290276410816,
        is_for_trade = 1,
    );
    assert call_premia = 757779299949279364;
    assert put_premia = 67080341964548764;


    let (call_premia, put_premia, _) = black_scholes( //0xa10d4fa15db33c9705=1288.4159705, 0xbb8000000000000000=1500
        sigma=0x1fffbab5b19cd700,
        // sigma=0xc7fe4eef9803657ba,  // 0xc7fe4eef9803657ba/2**61 = 99.9966959832
        time_till_maturity_annualized=0x3fedc436d567d20,  //0x3fedc436d567d20/2**61 = 0.12486088914
        strike_price=0xbb8000000000000000,  // 0xbb8000000000000000/2**61 = 1500
        underlying_price=0xa10d4fa15db33c9705,  // 0xa10d4fa15db33c9705=0xa10d4fa15db33c9705/2**61=1288.4159705
        risk_free_rate_annualized=0,
        is_for_trade = 1,
    );
    assert call_premia = 247449679631042980066;  // 247449679631042980066/2**61 = 107.314192095
    assert put_premia = 735329234914881769949;  // 735329234914881769949/2**61 = 318.898221595
    return ();
}
