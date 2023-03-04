%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.pow import pow

from math64x61 import Math64x61
from lib.math_64x61_extended import Math64x61_div_imprecise

from contracts.helpers import _get_value_of_position
from contracts.constants import (
    EMPIRIC_ORACLE_ADDRESS, EMPIRIC_ETH_USD_KEY, EMPIRIC_AGGREGATION_MODE
)
from contracts.types import Option


@external
func test_get_value_of_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) {
 
    tempvar tmp_address = EMPIRIC_ORACLE_ADDRESS;
    tempvar myeth_address;
    %{
        # Not all returned values are used atm, hence the 0s
        stop_mock = mock_call(
            ids.tmp_address, "get_spot_median", [145000000000, 8, 0, 0]
        )
        admin_address = 123 # doesnt matter in this test
        ids.myeth_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [1, 1, 18, 10 * 10**18, 0, admin_address, admin_address]).contract_address
    %}
 
    let option = Option(
        option_side = 1,
        maturity = 1669849199,
        strike_price = 0xbb8000000000000000,
        quote_token_address = 0x5a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426,
        base_token_address = myeth_address,
        option_type = 0,
    );
    let position_size = 100000000000000; // 0.0001*10**18
    let option_type = 0;  // 0 for call option
    let current_volatility = 0x2000000000000000;  // =1... as 0x2000000000000000 / 2**61
    let current_pool_balance = 0x6666920e4559665;  // =0.20000130104... as 0x6666920e4559665 / 2**61

    let (res) = _get_value_of_position(
        option, position_size, option_type, current_volatility, current_pool_balance
    );

    assert res = 227076445590131;
    %{ stop_mock() %}

    return ();
}