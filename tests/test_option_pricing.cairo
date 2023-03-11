// Wrapper for non viewed functions in option_pricing.cairo
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from option_pricing import std_normal_cdf, d1_d2, black_scholes



@external
func test_black_scholes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) {

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

@external
func setup_std_norm_cdf{syscall_ptr: felt*, range_check_ptr}(){

    %{
        given(
            x = strategy.integers(0, 800).map(lambda x: int((x / 100) * 2**61))
        )
        max_examples(200)
    %}

    return ();
}

@external
func test_std_norm_cdf{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(x: felt){
    
    let (res_cairo) = std_normal_cdf(x);

    %{
        from math import isclose
        from statistics import NormalDist

        res_py = NormalDist(0, 1).cdf(ids.x / 2**61)
        res_cairo = ids.res_cairo / 2**61

        assert isclose(res_cairo, res_py, rel_tol = 0.001)
    %}

    return();
}

@external
func setup_d1_d2{syscall_ptr: felt*, range_check_ptr}(){

    %{
        given(
            sigma = strategy.integers(1, 2_000).map(lambda x: int((x / 1_000) * 2**61)),
            ttm = strategy.integers(1, 500).map(lambda x: int((x / 1_000) * 2**61)),
            strike_price = strategy.integers(1, 10000).map(lambda x: int(x * 2**61)),
            underlying_price = strategy.integers(1, 10000).map(lambda x: int(x * 2**61)),
        )
        max_examples(200)
    %}

    return ();
}

@external
func test_d1_d2{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    sigma: felt,
    ttm: felt,
    strike_price: felt,
    underlying_price: felt,
){
    alloc_locals;
    
    let  risk_free_rate_annualized = 0;
    
    let (d_1, is_pos_d_1, d_2, is_pos_d_2) = d1_d2(
        sigma,
        ttm,
        strike_price,
        underlying_price,
        risk_free_rate_annualized,
    );

    %{  
        from math import log, isclose, sqrt
        Math64x61_FRACT_PART = 2**61

        sigma = ids.sigma / Math64x61_FRACT_PART
        ttm = ids.ttm / Math64x61_FRACT_PART
        strike_price = ids.strike_price / Math64x61_FRACT_PART 
        spot_price = ids.underlying_price / Math64x61_FRACT_PART 
        r = ids.risk_free_rate_annualized / Math64x61_FRACT_PART

        d1_num = log(spot_price / strike_price) + (r + (sigma ** 2)/2)*ttm
        d1_denom = sigma * sqrt(ttm)

        d1_py = d1_num / d1_denom
        d2_py = d1_py - sigma * sqrt(ttm)

        d_1_sign = 1 if ids.is_pos_d_1 else -1
        d_2_sign = 1 if ids.is_pos_d_2 else -1
        calculated_d_1 = d_1_sign * ids.d_1 / Math64x61_FRACT_PART
        calculated_d_2 = d_2_sign * ids.d_2 / Math64x61_FRACT_PART

        assert isclose(calculated_d_1, d1_py, rel_tol = 0.00001)
        assert isclose(calculated_d_2, d2_py, rel_tol = 0.00001)

    %}

    return();
}

@external
func setup_black_scholes_extreme_d{syscall_ptr: felt*, range_check_ptr}(){

    %{
        given(
            strike_price = strategy.integers(1, 100000).map(lambda x: int(x * 2**61)),
            underlying_price = strategy.integers(1, 100000).map(lambda x: int(x * 2**61)),
            is_for_trade = strategy.integers(0, 1)
        )
        max_examples(200)
    %}

    return ();
}

@external
func test_black_scholes_extreme_d{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    strike_price: felt,
    underlying_price: felt,
    is_for_trade: felt
) {

    alloc_locals;


    %{  
        if ids.is_for_trade == 1:
            expect_revert(error_message ="option_pricing.std_normal_cdf received X value higher than 8") 
    %}

    let (call_premia, put_premia, _) = black_scholes(
        sigma = 230584300921369, // 0.001, so that d is always extreme
        time_till_maturity_annualized = 230584300921369408,
        strike_price = strike_price,
        underlying_price = underlying_price,
        risk_free_rate_annualized = 69175290276410816,
        is_for_trade = is_for_trade,
    );

    %{
        from math import isclose

        desired_call_premia = int(max(0, ids.underlying_price - ids.strike_price) + (0.01 * 2**61))
        desired_put_premia = int(max(0, ids.strike_price - ids.underlying_price) + (0.01 * 2**61))

        error_msg = f"""
            Failed for:
            strike_price     = {ids.strike_price},
            underlying_price = {ids.underlying_price}
        """

        assert isclose(ids.call_premia, desired_call_premia, rel_tol = 0.0001), error_msg
        assert isclose(ids.put_premia, desired_put_premia, rel_tol = 0.0001), error_msg
    %}

    return ();
}
