%lang starknet

// Part of the main contract to not add complexity by having to transfer tokens between our own contracts
from interface_lptoken import ILPToken
from interface_option_token import IOptionToken

//  commented out code already imported in amm.cairo
//  from starkware.cairo.common.cairo_builtins import HashBuiltin


from helpers import max
from starkware.cairo.common.math import abs_value
from starkware.cairo.common.math_cmp import is_nn//, is_le
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_mul,
    uint256_add,
    uint256_sub,
    uint256_unsigned_div_rem,
)
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from openzeppelin.token.erc20.IERC20 import IERC20

from constants import (
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    TRADE_SIDE_SHORT,
    get_opposite_side
)




// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Storage vars
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

@storage_var
func lptoken_addr_for_given_pooled_token(pooled_token_addr: felt) -> (res: felt) {
}


// Option type that this pool corresponds to.
@storage_var
func option_type_() -> (option_type: felt) {
}


// Address of the underlying token (for example address of ETH or USD or...).
@storage_var
func underlying_token_addres() -> (res: felt) {
}


// Stores current value of volatility for given pool (option type) and maturity.
@storage_var
func pool_volatility(maturity: Int) -> (volatility: Math64x61_) {
}


// List of available options (mapping from 1 to n to available strike x maturity,
// for n+1 returns zeros).
@storage_var
func available_options(order_i: felt) -> (option_side: felt, maturity: felt, strike_price: felt) {
}


// Maping from option params to option address
@storage_var
func option_token_address(
    option_side: felt, maturity: felt, strike_price: felt
) -> (res: felt) {
}


// Mapping from option params to pool's position
@storage_var
func option_position(option_side: felt, maturity: felt, strike_price: felt) -> (res: felt) {
}


// total balance of underlying in the pool (owned by the pool)
// available balance for withdraw will be computed on-demand since
// compute is cheap, storage is expensive on StarkNet currently
// FIXME: do we need pooled_token_addr??? if not drop it, if yes, add it all over the place
@storage_var
func lpool_balance(pooled_token_addr: felt) -> (res: Uint256) {
}


// Locked capital owned by the pool... above is lpool_balance describing total capital owned
// by the pool. Ie lpool_balance = pool_locked_capital + pool's unlocked capital
// Note: capital locked by users is not accounted for here.
    // Simple example:
    // - start pool with no position
    // - user sells option (user locks capital), pool pays premia and does not lock capital
    // - there is more "IERC20.balanceOf" in the pool than "pool's locked capital + unlocked capital"
@storage_var
func pool_locked_capital() -> (res: felt) {
}


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// storage_var handlers and helpers
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


@view
func get_pool_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    maturity: Int
) -> (pool_volatility: Math64x61_) {
    let (pool_volatility_) = pool_volatility.read(pool_address, maturity);
    return (pool_volatility_,);
}


func set_pool_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    maturity: Int, volatility: Math64x61_
) {
    // volatility has to be above 1 (in terms of Math64x61.FRACT_PART units...
    // ie volatility = 1 is very very close to 0 and 100% volatility would be
    // volatility=Math64x61.FRACT_PART)
    assert_nn_le(volatility, VOLATILITY_UPPER_BOUND - 1);
    assert_nn_le(VOLATILITY_LOWER_BOUND, volatility);
    pool_volatility.write(pool_address, maturity, volatility);
    return ();
}


func get_unlocked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token_adress: felt
) -> (unlocked_capital: felt) {
    // Returns capital that is unlocked for immediate extraction/use.
    // This is for example ETH in case of ETH/USD CALL options.

    let (locked_capital) = pool_locked_capital.read();

    let (own_addr) = get_contract_address();
    // FIXME: fix this...
    let (contract_balance) = IERC20.balanceOf(
        contract_address = option_token_address,
        account = own_addr
    );
    let unlocked_capital = contract_balance - locked_capital;
    return (unlocked_capital = unlocked_capital);
}


func get_option_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_side: felt, maturity: felt, strike_price: felt
) -> (option_token_address: felt) {
    let (option_token_addr) = option_token_address.read(
        option_side, maturity, strike_price
    );
    return (option_token_address=option_token_addr);
}


func get_value_of_pool_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (value_of_position: Uint256) {
    // Returns a total value of pools position (sum of value of all options held by pool).

    //FIXME
}


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


// @external
// func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(...):
// sets pair, liquidity currency and hence the option type
// for example pair is ETH/USDC and this pool is only for ETH hence only call options are handled here
// FIXME: do we actually need two liquidity pools for one pair??? does it make sense to have 1 or 2 LPs?
// end

// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Provide/remove liquidity
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

// lptoken_amt * exchange_rate = underlying_amt
// @returns Math64x61 fp num
// func get_lptoken_exchange_rate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
//     pooled_token_addr: felt
// ) -> (exchange_rate: felt):
//     let (lpt_supply) = totalSupply()
//     let (own_addr) = get_contract_address()
//     let (reserves) = IERC20.balanceOf(contract_address=pooled_token_addr, account=own_addr)
//     let exchange_rate = Math64x61_div(lpt_supply, reserves)
//     return (exchange_rate)
// end


func get_lptokens_for_underlying{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt, underlying_amt: Uint256
) -> (lpt_amt: Uint256) {
    // Takes in underlying_amt in quote or base tokens (based on the pool being put/call).
    // Returns how much lp tokens correspond to capital of size underlying_amt

    alloc_locals;
    let (own_addr) = get_contract_address();

    let (free_capital) = get_unlocked_capital();
    let (value_of_position) = get_value_of_pool_position();
    let (value_of_pool) = uint256_add(free_capital, value_of_position);

    if (value_of_pool.low == 0) {
        return (underlying_amt,);
    }
    let (lpt_addr) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    let (lpt_supply) = ILPToken.totalSupply(contract_address=lpt_addr);
    let (quot, rem) = uint256_unsigned_div_rem(lpt_supply, value_of_pool);
    let (to_mint_low, to_mint_high) = uint256_mul(quot, underlying_amt);
    assert to_mint_high.low = 0;
    let (to_div_low, to_div_high) = uint256_mul(rem, underlying_amt);
    assert to_div_high.low = 0;
    let (to_mint_additional_quot, to_mint_additional_rem) = uint256_unsigned_div_rem(
        to_div_low, value_of_pool
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
    // Takes in lpt_amt in terms of amount of lp tokens.
    // Returns how much underlying in quote or base tokens (based on the pool being put/call)
    // corresponds to given lp tokens.

    alloc_locals;

    let (lpt_addr: felt) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    let (total_lpt: Uint256) = ILPToken.totalSupply(contract_address=lpt_addr);

    let (free_capital) = get_unlocked_capital();
    let (value_of_position) = get_value_of_pool_position();
    let (total_underlying_amt) = uint256_add(free_capital, value_of_position);

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

// FIXME: add unittest that
// amount = get_underlying_for_lptokens(addr, get_lptokens_for_underlying(addr, amount))
//ie that what you get for lptoken is what you need to get same amount of lptokens


// Mints LPToken
// Assumes the underlying token is already approved (directly call approve() on the token being
// deposited to allow this contract to claim them)
// amt is amount of underlying token to deposit (either in base or quote based on call or put pool)
@external
func deposit_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt, amt: Uint256
) {
    let (caller_addr) = get_caller_address();
    let (own_addr) = get_contract_address();

    // Transfer tokens to pool.
    // We can do this optimistically;
    // any later exceptions revert the transaction anyway. saves some sanity checks
    IERC20.transferFrom(
        contract_address=pooled_token_addr, sender=caller_addr, recipient=own_addr, amount=amt
    );

    // update the lpool_balance by the provided capital
    let (current_balance) = lpool_balance.read(pooled_token_addr);
    let (new_pb: Uint256, carry: felt) = uint256_add(current_balance, amt);
    assert carry = 0;
    lpool_balance.write(pooled_token_addr, new_pb);

    // Calculates how many lp tokens will be minted for given amount of provided capital.
    let (mint_amt) = get_lptokens_for_underlying(pooled_token_addr, amt);
    // Transfers the capital
    let (lpt_addr) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    // Mint LP tokens
    ILPToken.mint(contract_address=lpt_addr, to=caller_addr, amount=mint_amt);
    return ();
}

@external
func withdraw_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: felt, lp_token_amount: Uint256
) {
    // lp_token_amount is in terms of lp tokens, not underlying as deposit_liquidity

    alloc_locals;
    let (caller_addr_) = get_caller_address();
    local caller_addr = caller_addr_;
    let (own_addr) = get_contract_address();

    // Get the amount of underlying that corresponds to given amount of lp tokens
    let (underlying_amount) = get_underlying_for_lptokens(pooled_token_addr, lp_token_amount);

    with_attr error_message(
        "Not enough 'cash' available funds in pool. Wait for it to be released from locked capital"
    ):
        let (free_capital) = get_available_capital();
        assert_nn(free_capital - underlying_amount);
    end

    // Transfer underlying (base or quote depending on call/put)
    // We can do this transfer optimistically;
    // any later exceptions revert the transaction anyway. saves some sanity checks
    IERC20.transferFrom(
        contract_address=pooled_token_addr,
        sender=own_addr,
        recipient=caller_addr,
        amount=underlying_amount
    );

    // Burn LP tokens
    let (lpt_addr) = lptoken_addr_for_given_pooled_token.read(pooled_token_addr);
    ILPToken.burn(contract_address=lpt_addr, account=caller_addr, amount=lp_token_amount);

    // Update that the capital in the pool (including the locked capital).
    let (current_balance: Uint256) = lpool_balance.read(pooled_token_addr);
    let (new_pb: Uint256) = uint256_sub(current_balance, underlying_amount);
    lpool_balance.write(pooled_token_addr, new_pb);

    return ();
}


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Trade options
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #



// User increases its position (if user is long, it increases the size of its long,
// if he/she is short, the short gets increased).
// Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
// This corresponds to something like "mint_option_token", but does more, it also changes internal state of the pool
//   and realocates locked capital/premia and fees between user and the pool
//   for example how much capital is unlocked, how much is locked,...
func mint_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    currency_address: felt,
    amount: felt,
    amount_in_pool_currency: felt,
    option_side: felt,
    option_type: felt,
    maturity: felt,
    strike_price: felt,
    premia_including_fees: felt,
    underlying_price: felt,
) {
    // currency_address: felt,  // adress of token staked in the pool (ETH/USDC/...)
    // amount: felt,  // in base tokens (ETH in case of ETH/USDC)
    // option_side: felt,
    // option_type: felt,
    // maturity: felt,  // felt in seconds
    // strike: felt,  // in Math64x61
    // premia_including_fees: felt,  // in Math64x61 in either base or quote token
    // underlying_price: felt, // in Math64x61

    // FIXME: do we want to have the amount here as felt or do want it as uint256???
    alloc_locals;

    let (option_token_address) = get_option_token_address(
        option_side=side,
        maturity=maturity,
        strike_price=strike_price
    );

    // Make sure the contract is the one that user wishes to trade
    let (contract_option_type) = IOptionToken.option_type(option_token_address);
    let (contract_strike) = IOptionToken.strike(option_token_address);
    let (contract_maturity) = IOptionToken.maturity(option_token_address);
    let (contract_option_side) = IOptionToken.side(option_token_address);

    with_attr error_message("Required contract doesn't match the address.") {
        assert contract_option_type = option_type;
        assert contract_strike = strike_price;
        assert contract_maturity = maturity;
        assert contract_option_side = option_side;
    }

    if (option_side == TRADE_SIDE_LONG) {
        // FIXME: add amount_in_pool_currency
        _mint_option_token_long(
            currency_address=currency_address,
            option_token_address=option_token_address,
            amount=amount,
            premia_including_fees=premia_including_fees,
        );
    } else {
        // FIXME: add amount_in_pool_currency
        _mint_option_token_short(
            currency_address=currency_address,
            option_token_address=option_token_address,
            amount=amount,
            premia_including_fees=premia_including_fees,
            option_type=option_type,
            underlying_price=underlying_price,
        );
    }

    return ();
}

func _mint_option_token_long{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    currency_address: felt, option_token_address: felt, amount: felt, premia_including_fees: felt
) {
    alloc_locals;

    let (current_contract_address) = get_contract_address();
    let (user_address) = get_caller_address();

    // Mint tokens
    IOptionToken.mint(option_token_address, user_address, amount);

    // Move premia and fees from user to the pool
    IERC20.transferFrom(
        contract_address=currency_address,
        sender=user_address,
        recipient=current_contract_address,
        amount=premia_including_fees,
    );  // Transaction will fail if there is not enough fund on users account

    // Decrease unlocked capital by (amount - premia_including_fees)
    // We have storage_var only for locked, and unlocked is retrieved by subtracting
    // locked capital from total balance, to to decrease unlocked capital, increase locked
    let (current_locked_balance) = pool_locked_capital.read();
    // FIXME: pool is locking in capital only if there is no previous position to cover the user's
    // long... ie if pool's does not have sufficient long to "pass down to user", it has to lock in
    // capital
    // LOOK INTO BURN_OPTION_TOKEN FIXMEs FOR BETTER DESCRIPTION
    let (increase_by) = amount - premia_including_fees; // FIXME amount here is in terms of ETH always

    let new_locked_balance = current_locked_balance + increase_by;

    // Check that there is enough unlocked capital
    with_attr error_message("Not enough unlocked capital.") {
        let (unlocked_balance) = get_unlocked_capital(option_token_address);
        let (new_unlocked_balance) = unlocked_balance - increase_by;
        assert_nn(new_unlocked_balance);
    }

    pool_locked_capital.write(new_locked_balance);

    return ();
}

func _mint_option_token_short{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    currency_address: felt,
    option_token_address: felt,
    amount: felt,
    premia_including_fees: felt,
    option_type: felt,
    underlying_price: felt,
) {
    alloc_locals;

    let (current_contract_address) = get_contract_address();
    let (user_address) = get_caller_address();

    // Mint tokens
    IOptionToken.mint(option_token_address, user_address, amount);

    if (option_type == OPTION_PUT) {
        let amount_quote = Math64x61.mul(amount, underlying_price);
        let to_be_paid_by_user = amount_quote - premia_including_fees;
    } else {
        let to_be_paid_by_user = amount - premia_including_fees;
    }

    // Move (amount minus (premia minus fees)) from user to the pool
    IERC20.transferFrom(
        contract_address=currency_address,
        sender=user_address,
        recipient=current_contract_address,
        amount=to_be_paid_by_user,
    );
    
    // Increase unlocked capital by (fees - premia)
    let (current_locked_balance) = pool_locked_capital.read();
    let new_locked_balance = current_locked_balance - premia_including_fees;

    // FIXME: free up locked capital if the pool was short (the user that is trading to be short
    // is providing the locked capital instead of pool - in case the pool had a short position)
    // ie update new_locked_balance before writing it
    // LOOK INTO BURN_OPTION_TOKEN FIXMEs FOR BETTER DESCRIPTION

    with_attr error_message("Not enough capital") {
        assert_nn(new_locked_balance);
    }
       
    pool_locked_capital.write(new_locked_balance);

    // user goes short, locks in capital of size amount, the pool pays premia to the user and lastly user pays fees to the pool
    // increase unlocked capital by (fees - premia) (this might be happening in the amm.cairo)
    return ();
}

// User decreases its position (if user is long, it decreases the size of its long,
// if he/she is short, the short gets decreased).
// Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
// This corresponds to something like "burn_option_token", but does more, it also changes internal state of the pool
//   and realocates locked capital/premia and fees between user and the pool
//   for example how much capital is unlocked, how much is locked,...
func burn_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt,
    amount_in_pool_currency: felt,
    option_side: felt,
    option_type: felt,
    maturity: felt,
    strike_price: felt,
    premia_including_fees: felt,
    underlying_price: felt,
) {
    // option_side is the side of the token being closed

    alloc_locals;

    let (option_token_address) = get_option_token_address(
        option_side=side,
        maturity=maturity,
        strike_price=strike_price
    );

    // Make sure the contract is the one that user wishes to trade
    let (contract_option_type) = IOptionToken.option_type(option_token_address);
    let (contract_strike) = IOptionToken.strike(option_token_address);
    let (contract_maturity) = IOptionToken.maturity(option_token_address);
    let (contract_option_side) = IOptionToken.side(option_token_address);

    with_attr error_message("Required contract doesnt match the address.") {
        assert contract_option_type = option_type;
        assert contract_strike = strike_price;
        assert contract_maturity = maturity;
        assert contract_option_side = option_side;
    }

    if (option_side == TRADE_SIDE_LONG) {
        _burn_option_token_long(
            currency_address=currency_address,
            option_token_address=option_token_address,
            amount=amount,
            amount_in_pool_currency=amount_in_pool_currency,
            premia_including_fees=premia_including_fees,
        );
    } else {
        _burn_option_token_short(
            currency_address=currency_address,
            option_token_address=option_token_address,
            amount=amount,
            amount_in_pool_currency=amount_in_pool_currency,
            premia_including_fees=premia_including_fees,
            option_type=option_type,
            underlying_price=underlying_price,
        );
    }

    return ();
}

func _burn_option_token_long{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    currency_address: felt,
    option_token_address: felt,
    amount: felt,
    amount_in_pool_currency: felt,
    premia_including_fees: felt,
) {
    // option_side is the side of the token being closed
    // user is closing its long position -> freeing up pool's locked capital
    // (but only if pool is short, otherwise the locked capital was covered by other user)

    alloc_locals;

    let current_contract_address = get_contract_address();
    let user_address = get_caller_address();

    // Burn the tokens
    IOptionToken.burn(option_token_address, user_address, amount);

    IERC20.transferFrom(
        contract_address=currency_address,
        sender=current_contract_address,
        recipient=user_address,
        amount=premia_including_fees,
    );

    // Increase unlocked capital by (amount_in_pool_currency - (premia + fees))
    // FIXME:
    //  - in case the pool is long: the burn it increases pool's long
    //       -> the locked capital was locked by users and not pool -> do not decrease pool_locked_capital by the amount_in_pool_currency
    //  - in case the pool is short: the burn decreases the pool's short
    //      -> decrease the pool_locked_capital by the min(size of pool's short, amount_in_pool_currency)
    //          since the pool's short might not be covering all of the long
    // keep the description above (or a similar version)
    let (current_locked_balance) = pool_locked_capital.read();
    let decrease_locked_by = amount_in_pool_currency - premia_including_fees;
    let new_locked_balance = current_locked_balance - decrease_locked_by;

    pool_locked_capital.write(new_locked_balance);

    return ();
}

func _burn_option_token_short{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    currency_address: felt,
    option_token_address: felt,
    amount: felt,
    amount_in_pool_currency: felt,
    premia_including_fees: felt,
    option_type: felt,
    underlying_price: felt,
) {
    // option_side is the side of the token being closed

    alloc_locals;

    let current_contract_address = get_contract_address();
    let user_address = get_caller_address();

    // Burn the tokens
    IOptionToken.burn(option_token_address, user_address, amount);

    // User receives back its locked capital, pays premia and fees
    let total_user_payment = amount_in_pool_currency - premia_including_fees;

    IERC20.transferFrom(
        contract_address=currency_address,
        sender=current_contract_address,
        recipient=user_address,
        amount=total_user_payment,
    );

    // Increase unlocked capital by premia_including_fees
    // FIXME:
    //  - in case the pool is long: the burn decreases pool's long... up to a size of the pool's long
    //      -> if the amount_in_pool_currency > pool's long -> the pool starts to accumulate
    //          the short and has to lock in it's own capital... -> lock capital
    //      -> there might be a case, when there is not enough capital to be locked
    //          -> fail the transaction
    //  - in case the pool is short: the burn increases the pool's short
    //      -> increase the pool's locked capital by the amount_in_pool_currency
    //      -> there might be a case, when there is not enough capital to be locked
    // keep the description above (or a similar version)
    let (current_locked_balance) = pool_locked_capital.read();
    let new_locked_balance = current_locked_balance - premia_including_fees;

    with_attr error_message("Not enough capital") {
        assert_nn(new_locked_balance);
    }

    pool_locked_capital.write(new_locked_balance);
    // NOTICE: the unlocked capital does not get updated by amount, since it was never available for the pool
    return ();
}

// Once the option has expired return corresponding capital to the option owner
// for long call:
// return max(0, amount * (current_price - strike_price)) in ETH
// for short call:
// return amount - (max(0, amount * (current_price - strike_price)) in ETH)
// for long put:
// return max(0, amount * (strike_price - current_price)) in ETH
// for short put:
// return amount - (max(0, amount * (strike_price - current_price)) in ETH)


func expire_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt,
    option_side: felt,
    strike_price: felt,
    terminal_price: felt, // terminal price is price at which option is being settled
    option_size: felt,
    maturity: felt,
) {
    // EXPIRES OPTIONS ONLY FOR USERS (OPTION TOKEN HOLDERS) NOT FOR POOL.

    alloc_locals;

    let (option_token_address) = get_option_token_address(
        option_side=side,
        maturity=maturity,
        strike_price=strike_price
    );
    // FIXME
    let (currency_address) = 123;

    let (current_pool_position) = option_position.read(TRADE_SIDE_SHORT, maturity, strike_price);
    with_attr error_message("Pool hasn't released the locked capital for users -> call expire_option_token_for_pool to release it.") {
        // Even though the transaction might go through with no problems, there is a chance
        // of it failing or chance for pool manipulation.
        assert current_pool_position = 0;
    }

    // Make sure the contract is the one that user wishes to expire
    let (contract_option_type) = IOptionToken.option_type(option_token_address);
    let (contract_strike) = IOptionToken.strike(option_token_address);
    let (contract_maturity) = IOptionToken.maturity(option_token_address);
    let (contract_option_side) = IOptionToken.side(option_token_address);
    let (current_contract_address) = get_contract_address();

    with_attr error_message("Required contract doesn't match the address.") {
        assert contract_option_type = option_type;
        assert contract_strike = strike_price;
        assert contract_maturity = maturity;
        assert contract_option_side = option_side;
    }

    // Make sure that user owns the option tokens
    let (user_address) = get_caller_address();
    let (user_tokens_owned) = IOptionToken.balanceOf(
        contract_address=current_contract_address, account=user_address
    );
    with_attr error_message("User doesn't own any tokens.") {
        assert_nn(user_tokens_owned);
    }

    // Make sure that the contract is ready to expire
    let (current_block_time) = get_block_timestamp();
    let (is_ripe) = is_le(maturity, current_block_time);
    with_attr error_message("Contract isn't ripe yet.") {
        assert is_ripe = 1;
    }

    // long_value and short_value are both in terms of locked capital
    let (long_value, short_value) = split_option_locked_capital(
        option_type, option_side, option_size, strike_price, terminal_price
    );

    if (option_side == TRADE_SIDE_LONG) {
        // User is long
        // When user was long there is a possibility, that the pool is short,
        // which means that pool has locked in some capital.
        // We assume pool is able to "expire" it's functions pretty quickly so the updates
        // of storage_vars has already happened.
        IERC20.transferFrom(
            contract_address=currency_address,
            sender=current_contract_address,
            recipient=user_address,
            amount=long_value,
        );
    } else {
        // User is short
        // User locked in capital (no locking happened from pool - no locked capital and similar
        // storage vars were updated).
        IERC20.transferFrom(
            contract_address=currency_address,
            sender=current_contract_address,
            recipient=user_address,
            amount=short_value,
        );
    }

    return ();
}


func adjust_capital_for_pools_expired_options{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    long_value: felt,
    short_value: felt,
    option_size: felt,
    option_side: felt,
    maturity: felt,
    strike_price: felt
) {
    // This function is a helper function used only for expiring POOL'S options.
    // option_side is from perspektive of the pool

    alloc_locals

    // lpool_balance is total staked capital which has to be decreased by the "opposite" of adjust_by...

    let (current_lpool_balance) = lpool_balance.read();
    let (current_locked_balance) = pool_locked_capital.read();
    let (current_pool_position) = option_position.read(option_side, maturity, strike_price);

    let (new_pool_position) = current_pool_position - option_size
    option_position.write(option_side, maturity, strike_price, new_pool_position);

    if (option_side == TRADE_SIDE_LONG) {
        // Pool is LONG
        // Capital locked by user(s)
        // Increase lpool_balance by long_value, since pool either made profit (profit >=0).
        //      The cost (premium) was paid before.
        // Nothing locked by pool -> locked capital not affected
        // Unlocked capital should increas by profit from long option, in total:
        //      Unlocked capital = lpool_balance - pool_locked_capital
        //      diff_capital = diff_lpool_balance - diff_pool_locked
        //      diff_capital = long_value - 0

        let new_lpool_balance = current_lpool_balance + long_value;
        lpool_balance.write(pooled_token_addr, new_lpool_balance);
    } else {
        // Pool is SHORT
        // Decrease the lpool_balance by the long_value.
        //      The extraction of long_value might have not happened yet from transacting the tokens.
        //      But from perspective of accounting it is happening now.
        //          -> diff lpool_balance = -long_value
        // Decrease the pool_locked_capital by the locked capital. Locked capital for this option
        // (option_size * strike in terms of pool's currency (ETH vs USD))
        //          -> locked capital = long_value + short_value
        //          -> diff pool_locked_capital = - locked capital
        //      You may ask why not just the short_value. That is because the total capital
        //      (locked + unlocked) is decreased by long_value as in the point above (loss from short).
        //      The unlocked capital is increased by short_value - what gets returned from locked.
        //      To check the math
        //          -> lpool_balance = pool_locked_capital + unlocked
        //          -> diff lpool_balance = diff pool_locked_capital + diff unlocked
        //          -> -long_value = -locked capital + short_value
        //          -> -long_value = -(long_value + short_value) + short_value
        //          -> -long_value = -long_value - short_value + short_value
        //          -> -long_value +long_value = - short_value + short_value
        //          -> 0=0
        // The long value is left in the pool for the long owner to collect it.

        let new_lpool_balance = current_lpool_balance - long_value;
        let new_locked_balance = current_locked_balance - short_value - long_value;

        with_attr error_message("Not enough capital in the pool") {
            // This will never happen since the capital to pay the users is always locked.
            assert_nn(new_lpool_balance);
            assert_nn(new_locked_balance);
        }

        lpool_balance.write(pooled_token_addr, new_lpool_balance);
        pool_locked_capital.write(new_lpool_balance);
    }
    return ();
}


func split_option_locked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: felt,
    option_side: felt,
    option_size: felt,
    strike_price: felt,
    terminal_price: felt, // terminal price is price at which option is being settled
) -> (long_value: felt, short_value: felt) {
    alloc_locals;

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    if (option_type == OPTION_CALL) {
        // User receives max(0, option_size * (terminal_price - strike_price) / terminal_price) in base token for long
        // User receives (option_size - long_profit) for short
        let price_diff = terminal_price - strike_price;
        let to_be_paid_quote = option_size * price_diff;
        let to_be_paid_base = to_be_paid / terminal_price;
        let to_be_paid_buyer = max(0, to_be_paid_base);
        let to_be_paid_seller = option_size - to_be_paid_buyer;

        return (to_be_paid_buyer, to_be_paid_seller);
    }

    // For Put option
    // User receives  max(0, option_size * (strike_price - terminal_price)) in base token for long
    // User receives (option_size * strike_price - long_profit) for short
    let price_diff = strike_price - terminal_price;
    let amount_x_diff_quote = option_size * price_diff;
    let to_be_paid_buyer = max(0, amount_x_diff_quote);
    let to_be_paid_seller = option_size * strike_price - to_be_paid_buyer;

    return (to_be_paid_buyer, to_be_paid_seller);
}


@external
func expire_option_token_for_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_side: felt,
    strike_price: felt,
    maturity: felt,
) {

    alloc_locals;

    let (option_type) = option_type_.read();

    // pool's position... has to be nonnegative since the position is per side (long/short)
    let (option_size) = option_position.read(option_side, maturity, strike_price);
    assert_nn(option_size);
    if (option_size == 0){
        // Pool's position is zero, there is nothing to expire.
        // This also checks that the option exists (if it doesn't storage_var returns 0).
        return ();
    }
    // From now on we know that pool's position is positive -> option_size > 0.

    // Make sure the contract is ready to expire
    let (current_block_time) = get_block_timestamp();
    let (is_ripe) = is_le(maturity, current_block_time);
    with_attr error_message("Contract isn't mature yet") {
        assert is_ripe = 1;
    }

    // Get terminal price of the option.
    let (terminal_price) = FIXME;

    let (long_value, short_value)  = split_option_locked_capital(
        option_type, option_side, option_size, strike_price, terminal_price
    );

    adjust_capital_for_pools_expired_options(
        long_value=long_value,
        short_value=short_value,
        option_size=option_size,
        option_side=option_side,
        maturity=maturity,
        strike_price=strike_price
    );

    return ();
}
