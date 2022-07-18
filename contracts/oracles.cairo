%lang starknet

# List of available tickers:
#  https://docs.empiric.network/using-empiric/supported-assets

# TODO: Dont forget this is alpha-goerli address
const EMPIRIC_ORACLE_ADDRESS = 0x012fadd18ec1a23a160cc46981400160fbf4a7a5eed156c4669e39807265bcd4
const EMPIRIC_AGGREGATION_MODE = 0  # 0 is default for median

# Contract interface copied from docs
@contract_interface
namespace IEmpiricOracle:
    func get_value(key : felt, aggregation_mode : felt) -> (
        value : felt, decimals : felt, last_updated_timestamp : felt, num_sources_aggregated : felt
    ):
    end
end

# Function to collect median price of selected asset
@view
func empiric_median_price{syscall_ptr : felt*, range_check_ptr}(key : felt) -> (price : felt):
    let (
        value, decimals, last_updated_timestamp, num_sources_aggregated
    ) = IEmpiricOracle.get_value(EMPIRIC_ORACLE_ADDRESS, key, EMPIRIC_AGGREGATION_MODE)
    # TODO: Sanity checks for price, timestamp etc

    # returns price multiplied by 10**decimals for greater precision
    return (price=value)
end
