%lang starknet

# Part of the main contract to not add complexity by having to transfer tokens between our own contracts
from lptoken import mint, totalSupply

from Math64x61 import (  # prefix contracts because code is in lib/cairo_math_64x61/**contracts**/Math64x61.cairo
    Math64x61_fromFelt,
    Math64x61_mul,
    Math64x61_div,
    Math64x61_add,
    Math64x61_sub,
    Math64x61_min,
    Math64x61_ONE,
    Math64x61_fromUint256,
)
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_unsigned_div_rem
)
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
)
from openzeppelin.token.erc20.interfaces import IERC20



# # lptoken_amt * exchange_rate = underlying_amt
# # @returns Math64x61 fp num
# func get_lptoken_exchange_rate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
#     pooled_token_addr: felt
# ) -> (exchange_rate: felt):
#     let (lpt_supply) = totalSupply()
#     let (own_addr) = get_contract_address()
#     let (reserves) = IERC20.balanceOf(contract_address=pooled_token_addr, account=own_addr)
#     let (exchange_rate) = Math64x61_div(lpt_supply, reserves)
#     return (exchange_rate)
# end

func get_lptokens_for_underlying{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt,
    underlying_amt: Uint256
) -> (lpt_amt: Uint256):
    alloc_locals
    tempvar reserves = IERC20.balanceOf(contract_address=pooled_token_addr, account=own_addr)

    if reserves.low == 0:
        return (underlying_amt)
    end
    let (lpt_supply) = totalSupply()
    let (quot, rem) = uint256_unsigned_div_rem(lpt_supply, reserves)
    let (to_mint_low, to_mint_high) = uint256_mul(quot, underlying_amt)
    assert to_mint_high = 0
    let (to_div_low, to_div_high) = uint256_mul(rem, underlying_amt)
    assert to_div_high = 0
    let (to_mint_additional_quot, to_mint_additional_rem) = uint256_unsigned_div_rem(to_div_low, reserves)  # to_mint_additional_rem goes to liq pool // treasury
    let (mint_total, carry) = uint256_add(to_mint_additional_quot, to_mint_low)
    assert carry = 0
    return (mint_total)
end

# mints LPToken
# assumes the underlying token is already approved (directly call approve() on the token being deposited to allow this contract to claim them)
# amt is amt of underlying token to deposit
@external
func deposit_lp{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt,
    amt: Uint256
):
    let (caller_addr) =  get_caller_address()
    let (own_addr) = get_contract_address()
    tempvar balance_before = IERC20.balanceOf(contract_address=pooled_token_addr, account=own_addr)

    IERC20.transferFrom(
        contract_address=erc20_address,
        sender=caller_addr,
        recipient=own_addr,
        amount=amt,
    )  # we can do this optimistically; any later exceptions revert the transaction anyway. saves some sanity checks

    let (mint_amt) = get_lptokens_for_underlying(pooled_token_addr, amt)
    mint(caller_addr, resulting_amt_uint256)

    return ()
end
