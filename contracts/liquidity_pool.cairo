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

from option_tokens.logn_call_option import (
    mint as long_call_mint,
    burn as long_call_burn
)
from constants import (
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    TRADE_SIDE_SHORT,
    get_opposite_side
)



# @external
# func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(...):
    # sets pair, liquidity currency and hence the option type
    # for example pair is ETH/USDC and this pool is only for ETH hence only call options are handled here
    # FIXME: do we actually need two liquidity pools for one pair??? does it make sense to have 1 or 2 LPs?
# end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Provide/remove liquidity
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

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
# FIXME: could we call this deposit_liquidity
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


# FIXME: has to calculate value of the entire pool (available capital + value of options) and return proportion of it
# @external
# func remove_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
#     pooled_token_addr: felt,
#     amt: Uint256
# ):
#     # FIXME: TBD
# end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Trade options
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


# FIXME: do we have to move the functionality to amm.cairo or move most the functionality from amm.cairo here.
    # asking because I'm not sure about the addresses being correctly put through
    # ie if user calls amm.trade(...) that calls amm.do_trade(...) that calls different contract liquidity_pool.buy_call(...)
    # how does the premium and fee end up in the liquidity pool???
    # This might be nonsence, but I just don't know at the moment.


# User increases its position (if user is long, it increases the size of its long,
# if he/she is short, the short gets increased).
# Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
# This corresponds to something like "mint_option_token", but does more, it also changes internal state of the pool
#   and realocates locked capital/premia and fees between user and the pool
#   for example how much capital is available, how much is locked,...
func mint_option_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount: felt,
    option_type: felt,
    option_side: felt
):
    # FIXME: do we want to have the amount here as felt or do want it as uint256???

    # if option_type != correct option type -> fail
    # ie for call options only pool with ETH is used and for PUT options only the USDC is used

    # assuming we are in a CALL pool (ie ETH pool)

    if option_side == TRADE_SIDE_LONG:
        _mint_option_token_long(address, amount, strike, maturity)
    else:
        _mint_option_token_short(address, amount, strike, maturity)
end

func _mint_option_token_long{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address: felt,
    amount: felt,
    strike: felt,
    maturity: felt
):
    # address is user address
    long_call_mint(address, amount, strike, maturity)

    # move premia and fees from user to the pool

    # decrease available capital by (amount - premia - fees)... (this might be happening in the amm.cairo)
end

func _mint_option_token_short{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address: felt,
    amount: felt,
    strike: felt,
    maturity: felt
):
    # address is user address
    short_call_mint(address, amount, strike, maturity)

    # move (amount minus (premia minus fees)) from user to the pool
    # user goes short, locks in capital of size amount, the pool pays premia to the user and lastly user pays fees to the pool

    # increase available capital by (amount - premia + fees) (this might be happening in the amm.cairo)
end

# User decreases its position (if user is long, it decreases the size of its long,
# if he/she is short, the short gets decreased).
# Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
# This corresponds to something like "burn_option_token", but does more, it also changes internal state of the pool
#   and realocates locked capital/premia and fees between user and the pool
#   for example how much capital is available, how much is locked,...
func burn_option_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount: felt,
    option_type: felt,
    option_side: felt
):
    # FIXME: do we want to have the amount here as felt or do want it as uint256???

    # if option_type != correct option type -> fail
    # ie for call options only pool with ETH is used and for PUT options only the USDC is used

    # assuming we are in a CALL pool (ie ETH pool)

    if option_side == TRADE_SIDE_LONG:
        _burn_option_token_long(address, amount, strike, maturity)
    else:
        _burn_option_token_short(address, amount, strike, maturity)
end

func _burn_option_token_long{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address: felt,
    amount: felt,
    strike: felt,
    maturity: felt
):
    # address is user address
    long_call_burn(address, amount, strike, maturity)

    # user gets premia minus fees
    # pool updates its available capital (unlocks it)

    # increase available capital by (amount - premia + fees)... (this might be happening in the amm.cairo)
end

func _burn_option_token_short{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address: felt,
    amount: felt,
    strike: felt,
    maturity: felt
):
    # address is user address
    short_call_burn(address, amount, strike, maturity)

    # user receives back its locked capital, pays premia and fees
    # pool updates it available capital

    # increase available capital by (premia - fees) (this might be happening in the amm.cairo)
    # NOTICE: the available capital does not get updated by amount, since it was never available for the pool
end

# Once the option has expired return corresponding capital to the option owner
    # for long call:
        # return max(0, amount * (current_price - strike_price)) in ETH
    # for short call:
        # return amount - (max(0, amount * (current_price - strike_price)) in ETH)
    # for long put:
        # return max(0, amount * (strike_price - current_price)) in ETH
    # for short put:
        # return amount - (max(0, amount * (strike_price - current_price)) in ETH)
func expire_option_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount: felt,
    option_type: felt,
    option_side: felt,
    strike_price: felt
):
    # FIXME: tbd
    return ()
end
