# Internal of the AMM

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
# from starkware.cairo.common.hash import hash2
# from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem
# from starkware.starknet.common.syscalls import storage_read, storage_write

from contracts.option_pricing import black_scholes

# The maximum amount of token in a pool.
const POOL_BALANCE_UPPER_BOUND = 2 ** 64
# The maximum amount of token for account balance
const ACCOUNT_BALANCE_UPPER_BOUND = 2 ** 64
# The minimum and maximum volatility
const VOLATILITY_LOWER_BOUND = 0
const VOLATILITY_UPPER_BOUND = 2 ** 64

# Imagine Token A being ETH and Token B being USDC. Ie underlying asset is ETH/USDC
# TOKEN_A corresponds to ETH and TOKEN_B to USDC... Ie underlying asset is TOKEN_A/TOKEN_B
# Call pool is denominated in TOKEN_A (ETH) and Put pool in TOKEN_B (USDC). Denominated
# also means, that the liquidity is in given token.
# FIXME: look into how the tokens are actually identified
# FIXME: move the token identification to separate file
const TOKEN_A = 1
const TOKEN_B = 2

# option_type
# TOKEN_A is used as locked capital in OPTION_CALL
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


# Create list of options

#---------------storage_var handlers------------------

func set_pool_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt, balance : felt
):
    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0
    assert_nn_le(balance, POOL_BALANCE_UPPER_BOUND - 1)
    pool_balance.write(option_type, balance)
    return ()
end

func set_account_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt, token_type : felt, balance : felt
):
    assert (token_type - TOKEN_A) * (token_type - TOKEN_b) = 0
    assert_nn_le(balance, POOL_BALANCE_UPPER_BOUND - 1)
    account_balance.write(account_id, token_type, balance)
    return ()
end

func set_pool_option_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt,
    strike_price : felt,
    maturity : felt,
    side : felt,
    balance : felt
):
    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0
    assert (side - TRADE_SIDE_LONG) * (side - TRADE_SIDE_SHORT) = 0
    assert_nn_le(balance, POOL_BALANCE_UPPER_BOUND - 1)
    # FIXME: assert maturity
    # FIXME: assert side

    pool_option_balance.write(option_type, strike_price, maturity, side, balance)
    return ()
end

func set_pool_volatility{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : felt, maturity : felt, volatility : felt
):
    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0
    assert_nn_le(volatility, VOLATILITY_UPPER_BOUND - 1)
    assert_nn_le(VOLATILITY_LOWER_BOUND, volatility - 1)
    pool_volatility.write(option_type, maturity, balance)
    return ()
end



#---------------AMM logic------------------


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

    # 4) Get time till maturity

    # 5) risk free rate

    # 6) Get premia

    # 7) Get fees


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

# -----------------------------------------------



# FIXME: this will have to be replaced by sending tokens from wallet to the pool(s).
# Adds fake tokens to the given account and for both pools (call and put pools).
@external
func add_fake_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account_id : felt, amount_token_a : felt, amount_token_b : felt
):
    # 1) check that the final balance is below POOL_BALANCE_UPPER_BOUND with the additional amount
    let (pool_balance_call) = pool_balance.read(OPTION_CALL)
    let (pool_balance_put) = pool_balance.read(OPTION_PUT)

    assert_nn_le(pool_balance_call, POOL_BALANCE_UPPER_BOUND - 1 - amount_token_a)
    assert_nn_le(pool_balance_put, POOL_BALANCE_UPPER_BOUND - 1 - amount_token_b)

    # 2) check that the final balance is below POOL_BALANCE_UPPER_BOUND with the additional amount
    let (account_balance_call) = account_balance.read(account_id, TOKEN_A)
    let (account_balance_put) = account_balance.read(account_id, TOKEN_B)

    assert_nn_le(account_balance_call, ACCOUNT_BALANCE_UPPER_BOUND - 1 - amount_token_a)
    assert_nn_le(account_balance_put, ACCOUNT_BALANCE_UPPER_BOUND - 1 - amount_token_b)

    # 3) update pool_balance
    set_pool_balance(OPTION_CALL, pool_balance_call + amount_token_a)
    set_pool_balance(OPTION_PUT, pool_balance_put + amount_token_b)

    # 4) update account_balance
    set_account_balance(account_id, TOKEN_A, account_balance_call + amount_token_a)
    set_account_balance(account_id, TOKEN_B, account_balance_put + amount_token_b)
    return ()
end



# func account_balance(account_id : felt, token_type : felt) -> (balance : felt):
# end

# # A map from option type to the corresponding balance of the pool.
# @storage_var
# func pool_balance(option_type : felt) -> (balance : felt):
# end

# # Stores information about underwritten or bought options that the AMM could
# # use instead of minting a new option. If balance > 0 -> pool does not have to
# # mint new options if user wants to buy, balance < 0 means the same when
# # user wants to sell.
# @storage_var
# func pool_option_balance(
#     option_type : felt,
#     strike_price : felt,
#     maturity : felt,
#     side : felt
# ) -> (balance : felt):
# end

# # Stores current value of volatility for given pool (option type) and maturity.
# @storage_var
# func pool_volatility(option_type : felt, maturity : felt) -> (volatility : felt):


# FIXME: this is here only until we are able to send in test tokens
@external
func init_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_a : felt, token_b : felt
):
    # 1) set pool_balance
    set_pool_balance(token_type=OPTION_CALL, balance=12345)
    set_pool_balance(token_type=OPTION_PUT, balance=12345)
    
    # 2) Set pool_option_balance


    # 3) Set pool_volatility
    set_pool_volatility(OPTION_CALL, 1000, 100)
    set_pool_volatility(OPTION_PUT, 1000, 100)



    return ()
end