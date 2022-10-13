%lang starknet 

const EMPIRIC_ORACLE_ADDRESS = 0x012fadd18ec1a23a160cc46981400160fbf4a7a5eed156c4669e39807265bcd4;
const EMPIRIC_AGGREGATION_MODE = 0;  // 0 is default for median
const EMPIRIC_ETH_USD_KEY = 28556963469423460;

@contract_interface
namespace IEmpiricOracle {
    func get_value(key: felt, aggregation_mode: felt) -> (
        value: felt, decimals: felt, last_updated_timestamp: felt, num_sources_aggregated: felt
    ) {
    }
}

@view
func get_new_value{syscall_ptr: felt*, range_check_ptr}() -> (new_value: felt) {
    alloc_locals;

    let (
        value, decimals, last_updated_timestamp, num_sources_aggregated
    ) = IEmpiricOracle.get_value(EMPIRIC_ORACLE_ADDRESS, EMPIRIC_ETH_USD_KEY, EMPIRIC_AGGREGATION_MODE);

    return value;
}