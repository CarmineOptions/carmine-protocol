%lang starknet

// Part of the main contract to not add complexity by having to transfer tokens between our own contracts
from interface_lptoken import ILPToken
from option_token import OptionToken
# commented out code already imported in amm.cairo
# from starkware.cairo.common.cairo_builtins import HashBuiltin


from starkware.cairo.common.math import abs_value
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_mul,
    uint256_add,
    uint256_sub,
    uint256_unsigned_div_rem,
)
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from openzeppelin.token.erc20.IERC20 import IERC20

#from constants import (
#    OPTION_CALL,
#    OPTION_PUT,
#    TRADE_SIDE_LONG,
#    TRADE_SIDE_SHORT,
#    get_opposite_side
#)

// @external
// func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(...):
// sets pair, liquidity currency and hence the option type
// for example pair is ETH/USDC and this pool is only for ETH hence only call options are handled here
// FIXME: do we actually need two liquidity pools for one pair??? does it make sense to have 1 or 2 LPs?
// end

// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Provide/remove liquidity
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

// # lptoken_amt * exchange_rate = underlying_amt
// # @returns Math64x61 fp num
// func get_lptoken_exchange_rate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
//     pooled_token_addr: felt
// ) -> (exchange_rate: felt):
//     let (lpt_supply) = totalSupply()
//     let (own_addr) = get_contract_address()
//     let (reserves) = IERC20.balanceOf(contract_address=pooled_token_addr, account=own_addr)
//     let (exchange_rate) = Math64x61_div(lpt_supply, reserves)
//     return (exchange_rate)
// end

func get_lptokens_for_underlying{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt, underlying_amt: Uint256
) -> (lpt_amt: Uint256) {
    alloc_locals;
    let (own_addr) = get_contract_address();
    let (reserves: Uint256) = IERC20.balanceOf(
        contract_address=pooled_token_addr, account=own_addr
    );

    if (reserves.low == 0) {
        return (underlying_amt,);
    }
    let (lpt_addr) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    let (lpt_supply) = ILPToken.totalSupply(contract_address=lpt_addr);
    let (quot, rem) = uint256_unsigned_div_rem(lpt_supply, reserves);
    let (to_mint_low, to_mint_high) = uint256_mul(quot, underlying_amt);
    assert to_mint_high.low = 0;
    let (to_div_low, to_div_high) = uint256_mul(rem, underlying_amt);
    assert to_div_high.low = 0;
    let (to_mint_additional_quot, to_mint_additional_rem) = uint256_unsigned_div_rem(
        to_div_low, reserves
    );  // to_mint_additional_rem goes to liq pool // treasury
    let (mint_total, carry) = uint256_add(to_mint_additional_quot, to_mint_low);
    assert carry = 0;
    return (mint_total,);
}

// computes what amt of underlying corresponds to a given amt of lpt.
// Doesn't take into account whether this underlying is actually free to be withdrawn.
// computes this essentially: my_underlying = (total_underlying/total_lpt)*my_lpt
// notation used: ... = (a)*my_lpt = b
func get_underlying_for_lptokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt, lpt_amt: Uint256
) -> (underlying_amt: Uint256) {
    alloc_locals;
    let (lpt_addr: felt) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    let (total_lpt: Uint256) = ILPToken.totalSupply(contract_address=lpt_addr);
    let (total_underlying_amt: Uint256) = lpool_balance.read(pooled_token_addr);
    let (a_quot, a_rem) = uint256_unsigned_div_rem(total_underlying_amt, total_lpt);
    let (b_low, b_high) = uint256_mul(a_quot, lpt_amt);
    assert b_high.low = 0;  // bits that overflow uint256 after multiplication
    let (tmp_low, tmp_high) = uint256_mul(a_rem, lpt_amt);
    assert tmp_high.low = 0;
    let (to_burn_additional_quot, to_burn_additional_rem) = uint256_unsigned_div_rem(
        tmp_low, total_lpt
    );
    let (to_burn, carry) = uint256_add(to_burn_additional_quot, b_low);
    assert carry = 0;
    return (to_burn,);
}

    if reserves.low == 0:
        return (underlying_amt)
    end
    let (lpt_addr) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr)
    let (lpt_supply) = ILPToken.totalSupply(contract_address=lpt_addr)

    let (quot, rem) = uint256_unsigned_div_rem(lpt_supply, reserves)
    let (to_mint_low, to_mint_high) = uint256_mul(quot, underlying_amt)

    assert to_mint_high.low = 0

    let (to_div_low, to_div_high) = uint256_mul(rem, underlying_amt)

    assert to_div_high.low = 0

    let (to_mint_additional_quot, to_mint_additional_rem) = uint256_unsigned_div_rem(to_div_low, reserves)  # to_mint_additional_rem goes to liq pool // treasury
    let (mint_total, carry) = uint256_add(to_mint_additional_quot, to_mint_low)

    assert carry = 0
    return (mint_total)
end

# computes what amt of underlying corresponds to a given amt of lpt.
# Doesn't take into account whether this underlying is actually free to be withdrawn.
# computes this essentially: my_underlying = (total_underlying/total_lpt)*my_lpt
# notation used: ... = (a)*my_lpt = b
func get_underlying_for_lptokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt,
    lpt_amt: Uint256
) -> (underlying_amt: Uint256):
    alloc_locals
    let (lpt_addr: felt) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr)
    let (total_lpt: Uint256) = ILPToken.totalSupply(contract_address=lpt_addr)
    let (total_underlying_amt: Uint256) = lpool_balance.read(pooled_token_addr)
    let (a_quot, a_rem) = uint256_unsigned_div_rem(total_underlying_amt, total_lpt)
    let (b_low, b_high) = uint256_mul(a_quot, lpt_amt)
    assert b_high.low = 0 # bits that overflow uint256 after multiplication
    let (tmp_low, tmp_high) = uint256_mul(a_rem, lpt_amt)
    assert tmp_high.low = 0
    let (to_burn_additional_quot, to_burn_additional_rem) = uint256_unsigned_div_rem(tmp_low, total_lpt)
    let (to_burn, carry) = uint256_add(to_burn_additional_quot, b_low)
    assert carry = 0
    return (to_burn)
end

# total balance of underlying in the pool
# available balance for withdraw will be computed on-demand since
# compute is cheap, storage is expensive on StarkNet currently
@storage_var
func lpool_balance(pooled_token_addr: felt) -> (res: Uint256) {
}

@storage_var
func lptoken_addr_for_given_pooled_token(pooled_token_addr: felt) -> (res: felt) {
}

// mints LPToken
// assumes the underlying token is already approved (directly call approve() on the token being deposited to allow this contract to claim them)
// amt is amt of underlying token to deposit
// FIXME: could we call this deposit_liquidity
@external
func deposit_lp{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt, amt: Uint256
) {
    let (caller_addr) = get_caller_address();
    let (own_addr) = get_contract_address();
    let (balance_before: Uint256) = IERC20.balanceOf(
        contract_address=pooled_token_addr, account=own_addr
    );

    let (current_balance) = lpool_balance.read(pooled_token_addr);

    IERC20.transferFrom(
        contract_address=pooled_token_addr, sender=caller_addr, recipient=own_addr, amount=amt
    );  // we can do this optimistically; any later exceptions revert the transaction anyway. saves some sanity checks

    let (new_pb: Uint256, carry: felt) = uint256_add(current_balance, amt);
    assert carry = 0;
    lpool_balance.write(pooled_token_addr, new_pb);
    // let (new_cb: Uint256, carry: felt) = uint256_add(balance_before, amt)
    // assert carry = 0
    // contract_balance.write(new_cb)

    let (mint_amt) = get_lptokens_for_underlying(pooled_token_addr, amt);
    let (caller_addr) = get_caller_address();
    let (lpt_addr) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    ILPToken.mint(contract_address=lpt_addr, to=caller_addr, amount=mint_amt);
    return ();
}

@external
func withdraw_lp{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt, amt: Uint256
) {
    alloc_locals;
    let (caller_addr_) = get_caller_address();
    local caller_addr = caller_addr_;
    let (own_addr) = get_contract_address();
    let (balance_before: Uint256) = IERC20.balanceOf(
        contract_address=pooled_token_addr, account=own_addr
    );

    let (current_balance: Uint256) = lpool_balance.read(pooled_token_addr);

    // with_attr error_message("Not enough funds in pool"):
    //    assert_nn(current_balance - amt)
    //    assert_nn(balance_before - amt)
    // end

    let (new_pb: Uint256) = uint256_sub(current_balance, amt);
    lpool_balance.write(pooled_token_addr, new_pb);

    IERC20.transferFrom(
        contract_address=pooled_token_addr, sender=own_addr, recipient=caller_addr, amount=amt
    );  // we can do this optimistically; any later exceptions revert the transaction anyway. saves some sanity checks

    let (burn_amt) = get_underlying_for_lptokens(pooled_token_addr, amt);
    let (lpt_addr) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    ILPToken.burn(contract_address=lpt_addr, account=caller_addr, amount=burn_amt);

    return ();
}

// FIXME: has to calculate value of the entire pool (available capital + value of options) and return proportion of it
// @external
// func remove_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
//     pooled_token_addr: felt,
//     amt: Uint256
// ):
//     # FIXME: TBD
// end

// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Trade options
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

// FIXME: do we have to move the functionality to amm.cairo or move most the functionality from amm.cairo here.
// asking because I'm not sure about the addresses being correctly put through
// ie if user calls amm.trade(...) that calls amm.do_trade(...) that calls different contract liquidity_pool.buy_call(...)
// how does the premium and fee end up in the liquidity pool???
// This might be nonsence, but I just don't know at the moment.

// User increases its position (if user is long, it increases the size of its long,
// if he/she is short, the short gets increased).
// Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
// This corresponds to something like "mint_option_token", but does more, it also changes internal state of the pool
//   and realocates locked capital/premia and fees between user and the pool
//   for example how much capital is available, how much is locked,...
func mint_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, option_type: felt, option_side: felt
) {
    // FIXME: do we want to have the amount here as felt or do want it as uint256???

    // if option_type != correct option type -> fail
    // ie for call options only pool with ETH is used and for PUT options only the USDC is used

    // assuming we are in a CALL pool (ie ETH pool)

# User increases its position (if user is long, it increases the size of its long,
# if he/she is short, the short gets increased).
# Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
# This corresponds to something like "mint_option_token", but does more, it also changes internal state of the pool
#   and realocates locked capital/premia and fees between user and the pool
#   for example how much capital is available, how much is locked,...
func mint_option_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    currency_address: felt,  # adress of token staked in the pool (ETH/USDC/...)
    option_token_address: felt,
    amount: felt,  # in base tokens (ETH in case of ETH/USDC)
    option_side: felt,
    option_type: felt,
    maturity: felt,  # felt in seconds
    strike: felt,  # in Math64x61
    premia: felt,  # in Math64x61 in either base or quote token
    fees: felt  # in Math64x61 in either base or quote token
):
    # FIXME: do we want to have the amount here as felt or do want it as uint256???
    alloc_locals

    # Make sure the contract is the one that user wishes to trade
    let (contract_option_type) = OptionToken.option_type(option_token_address)
    let (contract_strike) = OptionToken.strike(option_token_address)
    let (contract_maturity) = OptionToken.maturity(option_token_address)
    let (contract_option_side) = OptionToken.side(option_token_address)

    with_attr error_message("Required contract doesnt match the address."):
        assert contract_option_type = option_type
        assert contract_strike = strike
        assert contract_maturity = maturity
        assert contract_option_side = side
    end

    if option_side == TRADE_SIDE_LONG:
        _mint_option_token_long(
            currency_address = currency_address,
            option_token_address = option_token_address,
            amount = amount,
            premia = premia,
            fees = fees

        )
    else:
        _mint_option_token_short(
            currency_address = currency_address,
            option_token_address = option_token_address,
            amount = amount,
            premia = premia,
            fees = fees

        )
    end

    return ()
end

func _mint_option_token_long{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    currency_address: felt,
    option_token_address: felt,
    amount: felt,
    premia: felt,
    fees: felt
):
    alloc_locals

    let (current_contract_address) = get_contract_address()
    let (user_address) = get_caller_address()

    # Mint tokens
    OptionToken.mint(option_token_address, user_address, amount)

    # User will pay (premia + fees)
    let to_be_paid_by_user = premia + fees

    # Move premia and fees from user to the pool
    IERC20.transferFrom(
        contract_address = currency_address,
        sender = user_address,
        recipient = current_contract_address,
        amount = to_be_paid_by_user
    ) # Transaction will fail if there is not enough fund on user's account

    # FIXME: Should the decreasing happen somewhere else? Ie OptionToken.mint function or the amm?
    # decrease available capital by (amount - premia - fees)... (this might be happening in the amm.cairo)
    return ()
end

func _mint_option_token_short{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    currency_address: felt,
    option_token_address: felt,
    amount: felt,
    premia: felt,
    fees: felt
):
    alloc_locals

    let (current_contract_address) = get_contract_address()
    let (user_address) = get_caller_address()

    # Mint tokens
    OptionToken.mint(option_token_address, user_address, amount)

    # User will pay (amount - (premia - fees)))
    let premia_less_fees = premia - fees
    # FIXME: amount has to be converted to quote token for PUT pool... amount := amount * strike_price
    let to_be_paid_by_user = amount - premia_les_fees

    # Move (amount minus (premia minus fees)) from user to the pool
    IERC20.transferFrom(
        contract_address = currency_address,
        sender = user_address,
        recipient = current_contract_address,
        amount = to_be_paid_by_user
    )

    # FIXME: Should happen somewhere else?
    # user goes short, locks in capital of size amount, the pool pays premia to the user and lastly user pays fees to the pool
    # increase available capital by (fees - premia) (this might be happening in the amm.cairo)
    return ()
end

# User decreases its position (if user is long, it decreases the size of its long,
# if he/she is short, the short gets decreased).
# Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
# This corresponds to something like "burn_option_token", but does more, it also changes internal state of the pool
#   and realocates locked capital/premia and fees between user and the pool
#   for example how much capital is available, how much is locked,...
func burn_option_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_token_address:felt,
    amount: felt,
    option_side: felt,
    option_type: felt,
    maturity: felt,
    strike: felt,
    premia: felt,
    fees: felt
):
    alloc_locals

    # Make sure the contract is the one that user wishes to trade
    let (contract_option_type) = OptionToken.option_type(option_token_address)
    let (contract_strike) = OptionToken.strike(option_token_address)
    let (contract_maturity) = OptionToken.maturity(option_token_address)
    let (contract_option_side) = OptionToken.side(option_token_address)

    with_attr error_message("Required contract doesnt match the address."):
        assert contract_option_type = option_type
        assert contract_strike = strike
        assert contract_maturity = maturity
        assert contract_option_side = side
    end

    if option_side == TRADE_SIDE_LONG:
        _burn_option_token_long(
            currency_address = currency_address,
            option_token_address = option_token_address,
            amount = amount,
            premia = premia,
            fees = fees

        )
    else:
        _burn_option_token_short(
            currency_address = currency_address,
            option_token_address = option_token_address,
            amount = amount,
            premia = premia,
            fees = fees

        )
    end

    return ()
end

func _burn_option_token_long{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    currency_address: felt,
    option_token_address: felt,
    amount: felt,
    premia: felt,
    fees: felt

):
    alloc_locals

    let current_contract_address = get_contract_address()
    let user_address = get_caller_address()

    # Burn the tokens
    OptionToken.burn(option_token_address, user_address, amount)

    # Send (premia - fees)  to user
    let to_be_received_by_user = premia - fees

    IERC20.transferFrom(
        contract_address = currency_address,
        sender = current_contract_address,
        recipient = user_address,
        amount = to_be_received_by_user
    )

    # FIXME: Should happen here or in OptionToken.burn() function?
    # pool updates its available capital (unlocks it)
    # increase available capital by (amount - premia + fees)... (this might be happening in the amm.cairo)
    return ()
end

func _burn_option_token_short{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    currency_address: felt,
    option_token_address: felt,
    amount: felt,
    premia: felt,
    fees: felt
):
    alloc_locals

    let current_contract_address = get_contract_address()
    let user_address = get_caller_address()

    # Burn the tokens
    OptionToken.burn(option_token_address, user_address, amount)

    # User pays (premia + fees)
    let to_be_paid_by_user = premia + fees

    # FIXME: Calculate unlocked capital for user
    # Retrieve locked capital to be paid to user
    # FIXME: amount has to be converted to quote token for PUT pool... amount := amount * strike_price
    let unlocked_capital_for_user = amount

    # User receives back its locked capital, pays premia and fees
    let total_user_payment = unlocked_capital_for_user - to_be_paid_by_user

    let (is_negative) = is_nn(total_user_payment)

    # If the amount is negative, user needs to pay us
    if is_negative == 1:
        # FIXME: throw an error with reasonable message instead of this transfer
        let abs_payment = abs_value(total_user_payment)
        IERC20.transferFrom(
            contract_address = currency_address,
            sender = user_address,
            recipient = current_contract_address,
            amount = abs_payment
        )

    else:
        IERC20.transferFrom(
            contract_address = currency_address,
            sender = current_contract_address,
            recipient = current_contract_address,
            amount = total_user_payment
        )

    end

    # FIXME: Should happen here?
    # pool updates it available capital
    # increase available capital by (premia - fees) (this might be happening in the amm.cairo)
    # NOTICE: the available capital does not get updated by amount, since it was never available for the pool
    return ()
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
