# Internal of the AMM

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
# from starkware.cairo.common.hash import hash2
# from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem
# from starkware.starknet.common.syscalls import storage_read, storage_write

from contracts.option_pricing import black_scholes

# The maximum amount of token in a pool.
const POOL_BALANCE_UPPER_BOUND = 2 ** 64

# Imagine Token A being ETH and Token B being USDC. Ie underlying asset is ETH/USDC
# TOKEN_A corresponds to ETH and TOKEN_B to USDC... Ie underlying asset is TOKEN_A/TOKEN_B
# Call pool is denominated in TOKEN_A (ETH) and Put pool in TOKEN_B (USDC). Denominated
# also means, that the liquidity is in given token.
# FIXME: look into how the tokens are actually identified
# FIXME: move the token identification to separate file
const TOKEN_A = 1
const TOKEN_B = 2

const OPTION_CALL = 0
const OPTION_PUT = 1

# This is used from perspective of user. When user goes long, the pool underwrites.
const TRADE_SIDE_LONG = 0
const TRADE_SIDE_SHORT = 1


# FIXME: look into how the token sizes are dealt with across different protocols
# A map from account and token type to the corresponding balance of that account in given pool.
# FIXME: This is at the moment not used.
@storage_var
func account_balance(account_id : felt, token_type : felt) -> (balance : felt):
end

# A map from option type to the corresponding balance of the pool.
@storage_var
func pool_balance(option_type : felt) -> (balance : felt):
end

# Stores information about underwritten or bought options that the AMM could
# use instead of minting a new option. If balance > 0 -> pool does not have to
# mint new options if user wants to buy, balance < 0 means the same when
# user wants to sell.
@storage_var
func pool_option_balance(
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt
) -> (balance : felt):
end

# Stores current value of volatility for given pool (option type) and maturity.
@storage_var
func pool_volatility(option_type : felt, maturity : felt) -> (volatility : felt):
end




func do_trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt,
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    option_size : felt,
):
    # 1) Calculate new volatility, calculate trade volatility

    # 2) Update volatility

    # 3) Get price of underlying asset

    # 4) Get premia

    # 5) Get fees


    # 1) Update the pool_balance
        # increase by the amount of fees (in corresponding TOKEN)
        # if side==TRADE_SIDE_LONG increase pool_balance by premia (in corresponding TOKEN)
        # if side==TRADE_SIDE_SHORT decrease pool_balance by premia (in corresponding TOKEN)

    # 2) get size of options that could be "traded" and not "minted" from pool_option_balance
    # if there are available ones, trade them, if not mint new ones
    # (could be partially traded and partially minted).
    let (available_option_balance) = 

    # available_option_balance is always >= 0
    let (to_be_traded) = min(available_option_balance, option_size)
    let (to_be_minted) = option_size - to_be_traded

    # 3) Update the pool_option_balance
        # decrease by to_be_traded
        # increase by to_be_minted
        # NOTE: the decrease and increase are of different storage var
            # (same option, but one storage var is for long, the other for short)

    # 4) Update the pool_balance
        # if side==TRADE_SIDE_SHORT increase pool_balance by
            # if option_type==OPTION_CALL increase (call pool) it by to_be_traded
            # if option_type==OPTION_PUT increase (put pool) it by to_be_traded*underlying_price
        # if side==TRADE_SIDE_LONG decrease pool_balance by
            # if option_type==OPTION_CALL decrease it by to_be_minted
            # if option_type==OPTION_PUT decrease it by to_be_minted*underlying_price



end

@external
func trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt,
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    option_size : felt,
):
    # option_type is from {OPTION_CALL, OPTION_PUT}
    # option_size is denominated in TOKEN_A (ETH)
    # side is from {TRADE_SIDE_LONG, TRADE_SIDE_SHORT}, where both are from user perspective,
        # ie "TRADE_SIDE_LONG" means that the pool is underwriting option and the "TRADE_SIDE_SHORT"
        # means that user is underwriting the option.

    # 1) Check that account_id has enough amount of given token to
        # - to pay the fee
        # - to pay the premia in case of size==TRADE_SIDE_LONG
        # - to lock in capital in case of size==TRADE_SIDE_SHORT
        # FIXME: do this once test or actual capital is used

    # 2) Check that there is enough available capital in the given pool_balance
        # - to pay the premia in case of size==TRADE_SIDE_LONG
        # - to lock in capital in case of size==TRADE_SIDE_SHORT

    # 3) Check that the strike_price > 0, check that the maturity haven't passed yet

    # 4) Check that the strike_price x maturity option is at all available

    # 5) Check that option_size>0

    do_trade(account_id, option_type, strike_price, maturity, side, option_size)

end


# FIXME: this will have to be replaced by sending tokens from wallet to the pool(s).
# Adds fake tokens to the given account and for both pools (call and put pools).
@external
func add_fake_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt, amount_token_a : felt, amount_token_b : felt
):
    # 1) check that the final balance is below POOL_BALANCE_UPPER_BOUND
    # 2) update pool_balance
    # 3) update account_balance
    return ()
end

# FIXME: this is here only until we are able to send in test tokens
@external
func init_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_a : felt, token_b : felt
):
    set_pool_token_balance(token_type=TOKEN_A, balance=12345)
    set_pool_token_balance(token_type=TOKEN_B, balance=12345)

    return ()
end