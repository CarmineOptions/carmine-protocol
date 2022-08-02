// Internals of the AMM

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.amm import (
    get_pool_balance,
    get_pool_volatility,
    get_pool_option_balance,
    get_account_balance,
    get_available_options,
    trade,
)
from contracts.option_pricing import black_scholes
from contracts.initialize_amm import init_pool, add_fake_tokens
from lib.cairo_contracts.src.openzeppelin.upgrades.library import Proxy

# Initializer

@external
func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proxy_admin : felt
):
    Proxy.initializer(proxy_admin)
    return ()
end

# Upgrades

@external
func upgrade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_implementation : felt
):
    Proxy.assert_only_admin()
    Proxy._set_implementation_hash(new_implementation)
    return ()
end

# Admin related functions

@view
func getAdmin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = Proxy.get_admin()
    return (address)
end

@external
func setAdmin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(address : felt):
    Proxy.assert_only_admin()
    Proxy._set_admin(address)
    return ()
end
