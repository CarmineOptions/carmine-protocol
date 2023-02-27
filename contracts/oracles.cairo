%lang starknet

from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem, assert_not_zero
from starkware.cairo.common.bool import TRUE, FALSE

from math64x61 import Math64x61

from contracts.constants import EMPIRIC_ORACLE_ADDRESS, EMPIRIC_AGGREGATION_MODE
from contracts.types import Int, Math64x61_, Address
from lib.math_64x61_extended import Math64x61_div_imprecise
from lib.pow import pow10

// List of available tickers:
//  https://docs.empiric.network/using-empiric/supported-assets

// Contract interface for Empiric Oracle
@contract_interface
namespace IEmpiricOracle {
    func get_spot_median(pair_id: felt) -> (
        price: felt, decimals: felt, last_updated_timestamp: felt, num_sources_aggregated: felt
    ) {
    }
    
    func get_last_spot_checkpoint_before(key: felt, timestamp: felt) -> (
        checkpoint: Checkpoint, idx: felt
    ) {
    }

    func get_spot(pair_id: felt, aggregation_mode: felt) -> (
        price: felt, decimals: felt, last_updated_timestamp: felt, num_sources_aggregated: felt
    ) {
    }
}

@contract_interface
namespace IChainlinkOracle {
    func latest_round_data() -> (round: Round) {
    }

    func round_data(round_id: felt) -> (round: Round) {
    }

    func decimals() -> (decimals: felt) {
    }
}

// Struct for terminal EMPIRIC price
struct Checkpoint {
    timestamp: felt,
    value: felt,
    aggregation_mode: felt,
    num_sources_aggregated: felt,
}

// Struct for Chainlink current price
struct Round {
    round_id: felt,
    answer: felt,
    block_num: felt,
    started_at: felt,
    updated_at: felt,
}

// Function to convert base 10**decimals number from oracle to base 2**61
// which is used throughout the AMM
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

    // FIXME: THIS HAS TO VALIDATED THAT THE ROUNDING CAUSED BY THE IMPRECISE CALCULATIONS IS NOT TOO BIG

    return (res,);
}

////////////////////////////
// Current Prices
////////////////////////////

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

// Note: Chainlink not currently on Mainnet
@view
func chainlink_current_price{syscall_ptr: felt*, range_check_ptr}(token_address: felt) -> (price: Math64x61_) {
    alloc_locals;

    with_attr error_message("Failed when getting current price from Chainlink Oracle") {
        let (current_round) = IChainlinkOracle.latest_round_data(token_address);
    }

    with_attr error_message("Failed when getting decimals from Chainlink Oracle") {
        let (decimals) = IChainlinkOracle.decimals(token_address);
    }

    with_attr error_message("Received zero current price from Chainlink Oracle") {
        assert_not_zero(current_round.answer);
    }

    with_attr error_message("Failed when converting Chainlink Oracle median price to Math64x61 format") {
        let (res) = convert_price(current_round.answer, decimals);
        assert_not_zero(res);
    }

    return (res,);
}

////////////////////////////
// Historical Prices
////////////////////////////

@view
func get_empiric_historical_price{syscall_ptr: felt*, range_check_ptr}(key: felt, maturity: Int) -> (
    price: Math64x61_
){
    alloc_locals;

    with_attr error_message("Failed when getting historical price from Empiric Oracle") {
    let (last_checkpoint,_) = IEmpiricOracle.get_last_spot_checkpoint_before(
            EMPIRIC_ORACLE_ADDRESS,
            key, 
            maturity
        );
    }

    with_attr error_message("Received zero historical price from Empiric Oracle"){
        assert_not_zero(last_checkpoint.value);
    }

    with_attr error_message("Failed when converting Empiric Oracle terminal price to Math64x61 format"){
        // Taken from the Empiric Docs, since Checkpoint does not
        // store this information, SHOULD NOT change in the future
        let decimals = 8;

        let (res)  = convert_price(
            last_checkpoint.value,
            decimals
        );

        assert_not_zero(res);
    }

    return (res,);
}


// Note: Chainlink not currently on Mainnet
@view
func get_chainlink_historical_price{syscall_ptr: felt*, range_check_ptr}(token_address: Address, maturity: Int) -> (
    price: Math64x61_
){
    alloc_locals;

    // TODO:
    // let round_id = get_roundid_from_maturity(maturity);
    let round_id = 1; // for compilation purposes
 
    with_attr error_message("Failed when getting historical price from Chainlink Oracle") {
        let (round) = IChainlinkOracle.round_data(
            token_address,
            round_id
        );
    }

    with_attr error_message("Received zero historical price from Chainlink Oracle"){
        assert_not_zero(round.answer);
    }
    
    with_attr error_message("Failed when getting decimals from Chainlink Oracle") {
        let (decimals) = IChainlinkOracle.decimals(token_address);
    }

    with_attr error_message("Failed when converting Chainlink Oracle historical price to Math64x61 format"){
    
        let (res)  = convert_price(
            round.answer,
            decimals
        );

        assert_not_zero(res);
    }

    return (res,);
}


@view
func get_terminal_price{syscall_ptr: felt*, range_check_ptr}(
    empiric_key: felt, // There will be more keys/addresses down the road
    maturity: Int
) -> (
    price: Math64x61_
){
    alloc_locals;

    // This is hotfix before the Chronos is up and running and is needed because empiric checkpoint is not working
    if (maturity == 1674777599) {
        return (3693960500760337711104,);
    }
    if (maturity == 1675987199) {
        return (3564833292244370849792,);
    }

    let (empiric_price) = get_empiric_historical_price(empiric_key, maturity);

    return (empiric_price,);
}



