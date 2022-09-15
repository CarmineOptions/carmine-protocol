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

// from constants import (
//     OPTION_CALL,
//     OPTION_PUT,
//     TRADE_SIDE_LONG,
//     TRADE_SIDE_SHORT,
//     get_opposite_side
// )

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
    alloc_locals;
    let (own_addr) = get_contract_address();
    // FIXME: reserves have to be calculated as value of pool's holdings
    // reserves = available unlocked capital + value of pool's position
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


// total balance of underlying in the pool (owned by the pool)
// available balance for withdraw will be computed on-demand since
// compute is cheap, storage is expensive on StarkNet currently
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
//     // FIXME: TBD
// end

// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Trade options
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


// Locked capital owned by the pool... above is lpool_balance describing total capital owned by the pool
// ie lpool_balance = pool_locked_capital + pool's unused capital
@storage_var
func pool_locked_capital() -> (res: felt) {
}

func get_option_token_unlocked_capital(option_token_adress: felt) -> (unlocked_capital: felt) {
    let (locked_capital) = pool_locked_capital.read();

    let (own_addr) = get_contract_address();
    let (contract_balance) = IERC20.balanceOf(
        contract_address = option_token_address,
        account = own_addr
    );
    let unlocked_capital = contract_balance - locked_capital;
    return (unlocked_capital = unlocked_capital);
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



func get_option_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_side: felt, maturity: felt, strike_price: felt
) -> (option_token_address: felt) {
    let (option_token_addr) = option_token_address.read(
        option_side, maturity, strike_price
    );
    return (option_token_address=option_token_addr);
}

// FIXME: do we have to move the functionality to amm.cairo or move most the functionality from amm.cairo here.
// asking because Im not sure about the addresses being correctly put through
// ie if user calls amm.trade(...) that calls amm.do_trade(...) that calls different contract liquidity_pool.buy_call(...)
// how does the premium and fee end up in the liquidity pool???
// This might be nonsence, but I just dont know at the moment.

// User increases its position (if user is long, it increases the size of its long,
// if he/she is short, the short gets increased).
// Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
// This corresponds to something like "mint_option_token", but does more, it also changes internal state of the pool
//   and realocates locked capital/premia and fees between user and the pool
//   for example how much capital is available, how much is locked,...
func mint_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    currency_address: felt,
    amount: felt,
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
        _mint_option_token_long(
            currency_address=currency_address,
            option_token_address=option_token_address,
            amount=amount,
            premia_including_fees=premia_including_fees,
        );
    } else {
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
    currency_address: felt, option_token_address: felt, amount: felt, premia: felt, fees: felt
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

    // Decrease available capital by (amount - premia_including_fees)
    // We have storage_var only for locked, and unlocked is retrieved by subtracting
    // locked capital from total balance, to to decrease unlocked capital, increase locked
    let (current_locked_balance) = pool_locked_capital.read();
    let (increase_by) = amount - premia_including_fees;

    let new_locked_balance = current_locked_balance + increase_by;

    // Check that there is enough unlocked capital
    with_attr error_message("Not enough available capital.") {
        let (unlocked_balance) = get_option_token_unlocked_capital(option_token_address);
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

    
    // Increase available capital by (fees - premia)
    let (current_locked_balance) = pool_locked_capital.read();
    let new_locked_balance = current_locked_balance - premia_including_fees;

    with_attr error_message("Not enough capital") {
        assert_nn(new_locked_balance);
    }
       
    pool_locked_capital.write(new_locked_balance);

    // user goes short, locks in capital of size amount, the pool pays premia to the user and lastly user pays fees to the pool
    // increase available capital by (fees - premia) (this might be happening in the amm.cairo)
    return ();
}

// User decreases its position (if user is long, it decreases the size of its long,
// if he/she is short, the short gets decreased).
// Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
// This corresponds to something like "burn_option_token", but does more, it also changes internal state of the pool
//   and realocates locked capital/premia and fees between user and the pool
//   for example how much capital is available, how much is locked,...
func burn_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt,
    option_side: felt,
    option_type: felt,
    maturity: felt,
    strike_price: felt,
    premia_including_fees: felt,
    underlying_price: felt,
) {
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
            premia_including_fees=premia_including_fees,
        );
    } else {
        _burn_option_token_short(
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

func _burn_option_token_long{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    currency_address: felt, option_token_address: felt, amount: felt, premia_including_fees: felt
) {
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

    // Increase available capital by (amount - (premia + fees))
    let (current_locked_balance) = pool_locked_capital.read();
    let decrease_locked_by = (amount - premia) + fees;
    let new_locked_balance = current_locked_balance - decrease_locked_by;

    pool_locked_capital.write(new_locked_balance);

    return ();
}

func _burn_option_token_short{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    currency_address: felt,
    option_token_address: felt,
    amount: felt,
    premia_including_fees: felt,
    option_type: felt,
    underlying_price: felt,
) {
    alloc_locals;

    let current_contract_address = get_contract_address();
    let user_address = get_caller_address();

    // Burn the tokens
    IOptionToken.burn(option_token_address, user_address, amount);

    // Retrieve locked capital to be paid to user
    if (option_type == OPTION_PUT) {
        let unlocked_capital_for_user = Math64x61.mul(strike_price, amount);
    } else {
        let unlocked_capital_for_user = amount;
    }

    // User receives back its locked capital, pays premia and fees
    let total_user_payment = unlocked_capital_for_user - premia_including_fees;

    IERC20.transferFrom(
        contract_address=currency_address,
        sender=current_contract_address,
        recipient=user_address,
        amount=total_user_payment,
    );

    // Increase available capital by premia_including_fees
    let (current_locked_balance) = pool_locked_capital.read();
    let new_locked_balance = current_locked_balance - premia_including_fees;

    with_attr error_message("Not enough capital") {
        assert_nn(new_locked_balance);
    }

    pool_locked_capital.write(new_locked_balance);
    // NOTICE: the available capital does not get updated by amount, since it was never available for the pool
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
    amount: felt,
    maturity: felt,
) {
    alloc_locals;

    let (option_token_address) = get_option_token_address(
        option_side=side,
        maturity=maturity,
        strike_price=strike_price
    );
    // FIXME
    let (currency_address) = 123;

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
        option_type, option_side, strike_price, strike_price, terminal_price
    );

    if (option_side == TRADE_SIDE_LONG) {
        IERC20.transferFrom(
            contract_address=currency_address,
            sender=current_contract_address,
            recipient=user_address,
            amount=long_value,
        );
        adjust_available_capital(short_value);
    } else {
        IERC20.transferFrom(
            contract_address=currency_address,
            sender=current_contract_address,
            recipient=user_address,
            amount=short_value,
        );
        adjust_available_capital(long_value);
    }

    return ();
}

func adjust_available_capital(adjust_by: felt) {
    let (current_locked_capital) = pool_locked_capital.read();
    let new_locked_capital = current_locked_capital - adjust_by;

    with_attr error_message("Not enough capital to expire option") {
        assert_nn(new_locked_capital);
    }

    pool_locked_capital.write(new_locked_balance);

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

func expire_option_token_for_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt,
    option_type: felt,
    option_side: felt,
    strike_price: felt,
    option_token_address: felt,
    maturity: felt,
    terminal_price: felt
) {
    alloc_locals;

    let (option_size) = 
   
    // Make sure the contract is the one that user wishes to expire
    let (contract_option_type) = IOptionToken.option_type(option_token_address);
    let (contract_strike) = IOptionToken.strike(option_token_address);
    let (contract_maturity) = IOptionToken.maturity(option_token_address);
    let (contract_option_side) = IOptionToken.side(option_token_address);
    let (current_contract_address) = get_contract_address();

    with_attr error_message("Required contract doesn't match the address.") {
        assert contract_option_type = option_type;
        assert contract_strike = strike;
        assert contract_maturity = maturity;
        assert contract_option_side = side;
    }

    // FIXME: Account for option type
    // Make sure the contract is ready to expire
    let (current_block_time) = get_block_timestamp();
    let (is_ripe) = is_le(maturity, current_block_time);
    with_attr error_message("Contract isn't mature yet") {
        assert is_ripe = 1;
    }

    let (long_value, short_value)  = split_option_locked_capital(
        option_type, option_side, option_size, strike_price, terminal_price
    );

    if (option_side == TRADE_SIDE_LONG) {
        adjust_available_capital(long_value);
    } else {
        adjust_available_capital(short_value);
    }

    return ();
}
