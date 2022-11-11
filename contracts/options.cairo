%lang starknet

// Functions related to option token minting, option accouting, ...

// FIXME: remove this external before going to mainnet
// Function for removing option 
// Currently removes only from available_options storage_var
// Beacuse it storing duplicate options would cause provide 
// wrong result when calculating value of pool's position
@external
func remove_option{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    index: felt
) {
    alloc_locals;

    // Assert that only admin can access this function
    Proxy.assert_only_admin();

    // Remove option at given index and shift remaining options to the left
    remove_and_shift_available_options(lptoken_address, index);

    return ();
}


@external
func add_option{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    option_side: OptionSide,
    maturity: Int,
    strike_price: Math64x61_,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    lptoken_address: Address,
    option_token_address_: Address,
    initial_volatility: Math64x61_,
){
    alloc_locals;

    // This function adds option to the pool.

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    // 1) Check that owner (and no other entity) is adding the lptoken
    Proxy.assert_only_admin();
    // Check that the option token being added is the right one
    // FIXME strike_price, option type, etc from option_token_address
    // possibly do this when getting rid of Math64x61 in external function inputs
    let (contract_option_type) = IOptionToken.option_type(option_token_address_);
    let (contract_strike) = IOptionToken.strike_price(option_token_address_);
    let (contract_maturity) = IOptionToken.maturity(option_token_address_);
    let (contract_option_side) = IOptionToken.side(option_token_address_);
    assert contract_strike = strike_price;
    assert contract_maturity = maturity;
    assert contract_option_type = option_type;
    assert contract_option_side = option_side;

    // 2) Update following
    let hundred = Math64x61.fromFelt(100);
    pool_volatility.write(lptoken_address, maturity, initial_volatility);
    append_to_available_options(
        option_side,
        maturity,
        strike_price,
        quote_token_address,
        base_token_address,
        option_type,
        lptoken_address
    );
    option_token_address.write(
        lptoken_address, option_side, maturity, strike_price, option_token_address_
    );

    return ();
}


// User increases its position (if user is long, it increases the size of its long,
// if he/she is short, the short gets increased).
// Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
// This corresponds to something like "mint_option_token", but does more, it also changes internal state of the pool
//   and realocates locked capital/premia and fees between user and the pool
//   for example how much capital is unlocked, how much is locked,...
func mint_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_size: Math64x61_, // in base tokens (ETH in case of ETH/USDC)
    option_size_in_pool_currency: Math64x61_,
    option_side: OptionSide,
    option_type: OptionType,
    maturity: Int, // in seconds
    strike_price: Math64x61_,
    premia_including_fees: Math64x61_, // either base or quote token
    underlying_price: Math64x61_,
) {

    alloc_locals;

    with_attr error_message("mint_option_token failed") {

        let (option_token_address) = get_option_token_address(
            lptoken_address=lptoken_address,
            option_side=option_side,
            maturity=maturity,
            strike_price=strike_price
        );

        // Make sure the contract is the one that user wishes to trade
        let (contract_option_type) = IOptionToken.option_type(option_token_address);
        let (contract_strike) = IOptionToken.strike_price(option_token_address);
        let (contract_maturity) = IOptionToken.maturity(option_token_address);
        let (contract_option_side) = IOptionToken.side(option_token_address);

        with_attr error_message("Required contract doesn't match the option_type specification.") {
            assert contract_option_type = option_type;
        }
        with_attr error_message("Required contract doesn't match the strike_price specification.") {
            assert contract_strike = strike_price;
        }
        with_attr error_message("Required contract doesn't match the maturity specification.") {
            assert contract_maturity = maturity;
        }
        with_attr error_message("Required contract doesn't match the option_side specification.") {
            assert contract_option_side = option_side;
        }

        if (option_side == TRADE_SIDE_LONG) {
            _mint_option_token_long(
                lptoken_address=lptoken_address,
                option_token_address=option_token_address,
                option_size=option_size,
                option_size_in_pool_currency=option_size_in_pool_currency,
                premia_including_fees=premia_including_fees,
                option_type=option_type,
                maturity=maturity,
                strike_price=strike_price,
            );
        } else {
            _mint_option_token_short(
                lptoken_address=lptoken_address,
                option_token_address=option_token_address,
                option_size=option_size,
                option_size_in_pool_currency=option_size_in_pool_currency,
                premia_including_fees=premia_including_fees,
                option_type=option_type,
                maturity=maturity,
                strike_price=strike_price,
                underlying_price=underlying_price,
            );
        }
    }

    return ();
}


func _mint_option_token_long{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_token_address: Address,
    option_size: Math64x61_,
    option_size_in_pool_currency: Math64x61_,
    premia_including_fees: Math64x61_,
    option_type: OptionType,
    maturity: Int,
    strike_price: Math64x61_,
) {
    alloc_locals;

    with_attr error_message("_mint_option_token_long failed") {
        let (current_contract_address) = get_contract_address();
        let (user_address) = get_caller_address();
        let (currency_address) = get_underlying_token_address(lptoken_address);
        let (pool_definition) = get_pool_definition_from_lptoken_address(lptoken_address);
        let base_address = pool_definition.base_token_address;

        with_attr error_message("_mint_option_token_long option_token_address is zero") {
            assert_not_zero(option_token_address);
        }
        with_attr error_message("_mint_option_token_long lptoken_address is zero") {
            assert_not_zero(lptoken_address);
        }
        with_attr error_message("_mint_option_token_long current_contract_address is zero") {
            assert_not_zero(current_contract_address);
        }
        with_attr error_message("_mint_option_token_long user_address is zero") {
            assert_not_zero(user_address);
        }
        with_attr error_message("_mint_option_token_long lptoken_address is zero") {
            assert_not_zero(lptoken_address);
        }
        with_attr error_message("_mint_option_token_long currency_address is zero") {
            assert_not_zero(currency_address);
        }
        with_attr error_message("_mint_option_token_long base_address is zero") {
            assert_not_zero(base_address);
        }

        // Mint tokens
        with_attr error_message("Failed to mint option token in _mint_option_token_long") {
            let option_size_uint256 = toUint256_balance(option_size, base_address);
            IOptionToken.mint(option_token_address, user_address, option_size_uint256);
        }

        // Move premia and fees from user to the pool
        with_attr error_message("Failed to convert premia_including_fees to Uint256 _mint_option_token_long") {
            let premia_including_fees_uint256 = toUint256_balance(premia_including_fees, currency_address);
        }

        let premia_including_fees_uint256_low = premia_including_fees_uint256.low;
        with_attr error_message(
            "Failed to transfer premia and fees _mint_option_token_long {currency_address}, {user_address}, {current_contract_address}, {premia_including_fees_uint256_low} {option_size}, {option_size_in_pool_currency}"
        ) {
            IERC20.transferFrom(
                contract_address=currency_address,
                sender=user_address,
                recipient=current_contract_address,
                amount=premia_including_fees_uint256,
            );  // Transaction will fail if there is not enough fund on users account
        }

        // Pool is locking in capital inly if there is no previous position to cover the user's long
        //      -> if pool does not have sufficient long to "pass down to user", it has to lock
        //           capital... option position has to be updated too!!!

        with_attr error_message("Failed to update lpool_balance in _mint_option_token_long") {
            // Increase lpool_balance by premia_including_fees -> this also increases unlocked capital
            // since only locked_capital storage_var exists
            let (current_balance) = lpool_balance.read(lptoken_address);
            let new_balance = Math64x61.add(current_balance, premia_including_fees);
            lpool_balance.write(lptoken_address, new_balance);
        }

        // Update pool's position, lock capital... lpool_balance was already updated above
        let (current_long_position) = option_position.read(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price
        );
        let (current_short_position) = option_position.read(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price
        );
        let (current_locked_balance) = pool_locked_capital.read(lptoken_address);

        with_attr error_message("Failed to convert amount in _mint_option_token_long") {
            // Get diffs to update everything
            let (decrease_long_by) = min(option_size, current_long_position);
            let increase_short_by = Math64x61.sub(option_size, decrease_long_by);
            let (increase_locked_by) = convert_amount_to_option_currency_from_base(increase_short_by, option_type, strike_price);
        }

        with_attr error_message("Failed to calculate new_locked_capital in _mint_option_token_long") {
            // New state
            let new_long_position = Math64x61.sub(current_long_position, decrease_long_by);
            let new_short_position = Math64x61.add(current_short_position, increase_short_by);
            let new_locked_capital = Math64x61.add(current_locked_balance, increase_locked_by);
        }

        // Check that there is enough capital to be locked.
        with_attr error_message("Not enough unlocked capital in pool") {
            let assert_res = Math64x61.sub(new_balance, new_locked_capital);
            assert_nn(assert_res);
        }

        with_attr error_message("Failed to update pool_locked_capital in _mint_option_token_long") {
            // Update the state
            option_position.write(lptoken_address, TRADE_SIDE_LONG, maturity, strike_price, new_long_position);
            option_position.write(lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price, new_short_position);
            pool_locked_capital.write(lptoken_address, new_locked_capital);
        }
    }

    return ();
}


func _mint_option_token_short{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_token_address: Address,
    option_size: Math64x61_,
    option_size_in_pool_currency: Math64x61_,
    premia_including_fees: Math64x61_,
    option_type: OptionType,
    maturity: Int,
    strike_price: Math64x61_,
    underlying_price: Math64x61_,
) {
    alloc_locals;

    with_attr error_message("_mint_option_token_short failed") {
        let (current_contract_address) = get_contract_address();
        let (user_address) = get_caller_address();
        let (currency_address) = get_underlying_token_address(lptoken_address);
        let (pool_definition) = get_pool_definition_from_lptoken_address(lptoken_address);
        let base_address = pool_definition.base_token_address;

        with_attr error_message("_mint_option_token_short option_token_address is zero") {
            assert_not_zero(option_token_address);
        }
        with_attr error_message("_mint_option_token_short lptoken_address is zero") {
            assert_not_zero(lptoken_address);
        }
        with_attr error_message("_mint_option_token_short current_contract_address is zero") {
            assert_not_zero(current_contract_address);
        }
        with_attr error_message("_mint_option_token_short user_address is zero") {
            assert_not_zero(user_address);
        }
        with_attr error_message("_mint_option_token_short lptoken_address is zero") {
            assert_not_zero(lptoken_address);
        }
        with_attr error_message("_mint_option_token_short currency_address is zero") {
            assert_not_zero(currency_address);
        }
        with_attr error_message("_mint_option_token_short base_address is zero") {
            assert_not_zero(base_address);
        }

        // Mint tokens
        let option_size_uint256 = toUint256_balance(option_size, base_address);
        IOptionToken.mint(option_token_address, user_address, option_size_uint256);

        let to_be_paid_by_user = Math64x61.sub(option_size_in_pool_currency, premia_including_fees);

        // Move (option_size minus (premia minus fees)) from user to the pool
        let to_be_paid_by_user_uint256 = toUint256_balance(to_be_paid_by_user, currency_address);
        IERC20.transferFrom(
            contract_address=currency_address,
            sender=user_address,
            recipient=current_contract_address,
            amount=to_be_paid_by_user_uint256,
        );

        // Decrease lpool_balance by premia_including_fees -> this also decreases unlocked capital
        // since only locked_capital storage_var exists
        let (current_balance) = lpool_balance.read(lptoken_address);
        let new_balance = Math64x61.sub(current_balance, premia_including_fees);
        lpool_balance.write(lptoken_address, new_balance);

        // User is going short, hence user is locking in capital...
        //      if pool has short position -> unlock pool's capital
        // pools_position is in terms of base tokens (ETH in case of ETH/USD)...
        //      in same units is option_size
        // since user wants to go short, the pool can "sell off" its short... and unlock its capital

        // Update pool's short position
        let (pools_short_position) = option_position.read(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price
        );
        let (size_to_be_unlocked_in_base) = min(option_size, pools_short_position);
        let new_pools_short_position = Math64x61.sub(pools_short_position, size_to_be_unlocked_in_base);
        option_position.write(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price, new_pools_short_position
        );

        // Update pool's long position
        let (pools_long_position) = option_position.read(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price
        );
        let size_to_increase_long_position = Math64x61.sub(option_size, size_to_be_unlocked_in_base);
        let new_pools_long_position = Math64x61.add(pools_long_position, size_to_increase_long_position);
        option_position.write(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price, new_pools_long_position
        );

        // Update the locked capital
        let (size_to_be_unlocked) = convert_amount_to_option_currency_from_base(
            size_to_be_unlocked_in_base, option_type, strike_price
        );
        let (current_locked_balance) = pool_locked_capital.read(lptoken_address);
        let new_locked_balance = Math64x61.sub(current_locked_balance, size_to_be_unlocked);

        with_attr error_message("Not enough capital") {
            // This will never happen. It is here just as sanity check.
            assert_nn(new_locked_balance);
        }

        pool_locked_capital.write(lptoken_address, new_locked_balance);
    }

    return ();
}

// User decreases its position (if user is long, it decreases the size of its long,
// if he/she is short, the short gets decreased).
// Switching position from long to short requires both mint_option_token and burn_option_token functions to be called.
// This corresponds to something like "burn_option_token", but does more, it also changes internal state of the pool
//   and realocates locked capital/premia and fees between user and the pool
//   for example how much capital is unlocked, how much is locked,...
func burn_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_size: Math64x61_,
    option_size_in_pool_currency: Math64x61_,
    option_side: OptionSide,
    option_type: OptionType,
    maturity: Int,
    strike_price: Math64x61_,
    premia_including_fees: Math64x61_,
    underlying_price: Math64x61_,
) {
    // option_side is the side of the token being closed

    alloc_locals;

    let (option_token_address) = get_option_token_address(
        lptoken_address=lptoken_address,
        option_side=option_side,
        maturity=maturity,
        strike_price=strike_price
    );

    // Make sure the contract is the one that user wishes to trade
    let (contract_option_type) = IOptionToken.option_type(option_token_address);
    let (contract_strike) = IOptionToken.strike_price(option_token_address);
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
            lptoken_address=lptoken_address,
            option_token_address=option_token_address,
            option_size=option_size,
            option_size_in_pool_currency=option_size_in_pool_currency,
            premia_including_fees=premia_including_fees,
            option_side = option_side,
            option_type=option_type,
            maturity = maturity,
            strike_price=strike_price,
        );
    } else {
        _burn_option_token_short(
            lptoken_address=lptoken_address,
            option_token_address=option_token_address,
            option_size=option_size,
            option_size_in_pool_currency=option_size_in_pool_currency,
            premia_including_fees=premia_including_fees,
            option_side=option_size,
            option_type=option_type,
            maturity=maturity,
            strike_price=strike_price,
        );
    }
    return ();
}


func _burn_option_token_long{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_token_address: Address,
    option_size: Math64x61_,
    option_size_in_pool_currency: Math64x61_,
    premia_including_fees: Math64x61_,
    option_side: OptionSide,
    option_type: OptionType,
    maturity: Int,
    strike_price: Math64x61_,
) {
    // option_side is the side of the token being closed
    // user is closing its long position -> freeing up pool's locked capital
    // (but only if pool is short, otherwise the locked capital was covered by other user)

    alloc_locals;

    let (current_contract_address) = get_contract_address();
    let (user_address) = get_caller_address();
    let (currency_address) = get_underlying_token_address(lptoken_address);
    let (pool_definition) = get_pool_definition_from_lptoken_address(lptoken_address);
    let base_address = pool_definition.base_token_address;

    // Burn the tokens
    let option_size_uint256 = toUint256_balance(option_size, base_address);
    IOptionToken.burn(option_token_address, user_address, option_size_uint256);

    let premia_including_fees_uint256 = toUint256_balance(premia_including_fees, currency_address);
    IERC20.transfer(
        contract_address=currency_address,
        recipient=user_address,
        amount=premia_including_fees_uint256,
    );

    // Decrease lpool_balance by premia_including_fees -> this also decreases unlocked capital
    // This decrease is happening because burning long is similar to minting short,
    // hence the payment.
    let (current_balance) = lpool_balance.read(lptoken_address);
    let new_balance = Math64x61.sub(current_balance, premia_including_fees);
    lpool_balance.write(lptoken_address, new_balance);

    let (pool_short_position) = option_position.read(
        lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price
    );
    let (pool_long_position) = option_position.read(
        lptoken_address, TRADE_SIDE_LONG, maturity, strike_price
    );

    if (pool_short_position == 0){
        // If pool is LONG:
        // Burn long increases pool's long (if pool was already long)
        //      -> The locked capital was locked by users and not pool
        //      -> do not decrease pool_locked_capital by the option_size_in_pool_currency
        let new_option_position = Math64x61.add(pool_long_position, option_size);
        option_position.write(
            lptoken_address,
            option_side,
            maturity,
            strike_price,
            new_option_position
        );
    } else {
        // If pool is SHORT
        // Burn decreases the pool's short
        //     -> decrease the pool_locked_capital by
        //        min(size of pools short, amount_in_pool_currency)
        //        since the pools' short might not be covering all of the long

        let (current_locked_balance) = pool_locked_capital.read(lptoken_address);
        let (size_to_be_unlocked_in_base) = min(pool_short_position, option_size);
        let (size_to_be_unlocked) = convert_amount_to_option_currency_from_base(
            size_to_be_unlocked_in_base, option_type, strike_price
        );
        let new_locked_balance = Math64x61.sub(current_locked_balance, size_to_be_unlocked);
        pool_locked_capital.write(lptoken_address, new_locked_balance);

        // Update pool's short position
        let (pools_short_position) = option_position.read(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price
        );
        let new_pools_short_position = Math64x61.sub(pools_short_position, size_to_be_unlocked_in_base);
        option_position.write(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price, new_pools_short_position
        );

        // Update pool's long position
        let (pools_long_position) = option_position.read(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price
        );
        let size_to_increase_long_position = Math64x61.sub(option_size, size_to_be_unlocked_in_base);
        let new_pools_long_position = Math64x61.add(pools_long_position, size_to_increase_long_position);
        option_position.write(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price, new_pools_long_position
        );
    }
    return ();
}


func _burn_option_token_short{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_token_address: Address,
    option_size: Math64x61_,
    option_size_in_pool_currency: Math64x61_,
    premia_including_fees: Math64x61_,
    option_side: OptionSide,
    option_type: OptionType,
    maturity: Int,
    strike_price: Math64x61_,
) {
    // option_side is the side of the token being closed

    alloc_locals;

    let (current_contract_address) = get_contract_address();
    let (user_address) = get_caller_address();
    let (currency_address) = get_underlying_token_address(lptoken_address);
    let (pool_definition) = get_pool_definition_from_lptoken_address(lptoken_address);
    let base_address = pool_definition.base_token_address;

    // Burn the tokens
    let option_size_uint256 = toUint256_balance(option_size, base_address);
    IOptionToken.burn(option_token_address, user_address, option_size_uint256);

    // User receives back its locked capital, pays premia and fees
    let total_user_payment = Math64x61.sub(option_size_in_pool_currency, premia_including_fees);
    let total_user_payment_uint256 = toUint256_balance(total_user_payment, currency_address);
    IERC20.transfer(
        contract_address=currency_address,
        recipient=user_address,
        amount=total_user_payment_uint256,
    );

    // Increase lpool_balance by premia_including_fees -> this also increases unlocked capital
    // This increase is happening because burning short is similar to minting long,
    // hence the payment.
    let (current_balance) = lpool_balance.read(lptoken_address);
    let new_balance = Math64x61.add(current_balance, premia_including_fees);
    lpool_balance.write(lptoken_address, new_balance);

    // Find out pools position... if it has short position = 0 -> it is long or at 0
    let (pool_short_position) = option_position.read(
        lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price
    );

    // FIXME: the inside of the if (not the else) should work for both cases
    if (pool_short_position == 0) {
        // If pool is LONG
        // Burn decreases pool's long -> up to a size of the pool's long 
        //      -> if option_size_in_pool_currency > pool's long -> pool starts to accumulate
        //         the short and has to lock in it's own capital -> lock capital
        //      -> there might be a case, when there is not enough capital to be locked -> fail
        //         the transaction

        let (pool_long_position) = option_position.read(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price
        );

        let (decrease_long_position_by) = min(pool_long_position, option_size);
        let increase_short_position_by = Math64x61.sub(option_size, decrease_long_position_by);
        let new_long_position = Math64x61.sub(pool_long_position, decrease_long_position_by);
        let new_short_position = Math64x61.add(pool_short_position, increase_short_position_by);

        // The increase_short_position_by and capital_to_be_locked might both be zero,
        // if the long position is sufficient.
        let (capital_to_be_locked) = convert_amount_to_option_currency_from_base(
            increase_short_position_by,
            option_type,
            strike_price
        );
        let (current_locked_capital) = pool_locked_capital.read(lptoken_address);
        let new_locked_capital = Math64x61.add(current_locked_capital, capital_to_be_locked);

        // Set the option positions
        option_position.write(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price, new_long_position
        );
        option_position.write(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price, new_short_position
        );

        // Set the pool_locked_capital.
        pool_locked_capital.write(lptoken_address, new_locked_capital);

        // Assert there is enough capital to be locked
        with_attr error_message("Not enough capital to be locked.") {
            assert_nn(new_balance - new_locked_capital);
        }

        tempvar syscall_ptr: felt* = syscall_ptr;
        tempvar pedersen_ptr: HashBuiltin* = pedersen_ptr;
    } else {
        // If pool is SHORT
        // Burn increases pool's short
        //      -> increase pool's locked capital by the option_size_in_pool_currency
        //      -> there might not be enough unlocked capital to be locked
        let (current_locked_capital) = pool_locked_capital.read(lptoken_address);
        let (current_total_capital) = lpool_balance.read(lptoken_address);
        let current_unlocked_capital = Math64x61.sub(current_total_capital, current_locked_capital);

        with_attr error_message("Not enough unlocked capital."){
            assert_nn(current_unlocked_capital - option_size_in_pool_currency);
        }

        // Update locked capital
        let new_locked_capital = Math64x61.add(current_locked_capital, option_size_in_pool_currency);
        pool_locked_capital.write(lptoken_address, new_locked_capital);

        // Update pools (short) position
        let (pools_short_position) = option_position.read(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price
        );
        let new_pools_short_position = Math64x61.sub(pools_short_position, option_size);
        option_position.write(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price, new_pools_short_position
        );

        tempvar syscall_ptr: felt* = syscall_ptr;
        tempvar pedersen_ptr: HashBuiltin* = pedersen_ptr;
    }

    return ();
}


func expire_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_type: OptionType,
    option_side: OptionSide,
    strike_price: Math64x61_,
    terminal_price: Math64x61_,
    option_size: Math64x61_,
    maturity: Int,
) {
    // EXPIRES OPTIONS ONLY FOR USERS (OPTION TOKEN HOLDERS) NOT FOR POOL.
    // terminal price is price at which option is being settled

    alloc_locals;

    let (option_token_address) = get_option_token_address(
        lptoken_address=lptoken_address,
        option_side=option_side,
        maturity=maturity,
        strike_price=strike_price
    );

    let (currency_address) = get_underlying_token_address(lptoken_address);

    // The option (underlying asset x maturity x option type x strike) has to be "expired"
    // (settled) on the pool's side in terms of locked capital. Ie check that SHORT position
    // has been settled, if pool is LONG then it did not lock capital and we can go on.
    let (current_pool_position) = option_position.read(
        lptoken_address,TRADE_SIDE_SHORT, maturity, strike_price
    );
    with_attr error_message(
        "Pool hasn't released the locked capital for users -> call expire_option_token_for_pool to release it."
    ) {
        // Even though the transaction might go through with no problems, there is a chance
        // of it failing or chance for pool manipulation if the pool hasn't released the capital yet.
        assert current_pool_position = 0;
    }

    // Make sure the contract is the one that user wishes to expire
    let (contract_option_type) = IOptionToken.option_type(option_token_address);
    let (contract_strike) = IOptionToken.strike_price(option_token_address);
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
        contract_address=option_token_address, account=user_address
    );
    with_attr error_message("User doesn't own any tokens.") {
        assert_nn(user_tokens_owned.low);
    }

    // Make sure that the contract is ready to expire
    let (current_block_time) = get_block_timestamp();
    let is_ripe = is_le(maturity, current_block_time);
    with_attr error_message("Contract isn't ripe yet.") {
        assert is_ripe = 1;
    }

    // long_value and short_value are both in terms of locked capital
    let (long_value, short_value) = split_option_locked_capital(
        option_type, option_side, option_size, strike_price, terminal_price
    );
    let (currency_address) = get_underlying_token_address(lptoken_address);
    let long_value_uint256 = toUint256_balance(long_value, currency_address);
    let short_value_uint256 = toUint256_balance(short_value, currency_address);

    // Validate that the user is not burning more than he/she has.
    let (pool_definition) = get_pool_definition_from_lptoken_address(lptoken_address);
    let base_address = pool_definition.base_token_address;
    let option_size_uint256 = toUint256_balance(option_size, base_address);
    with_attr error_message("option_size is higher than tokens owned by user") {
        // FIXME: this might be failing because of rounding when converting between
        // Match64x61 adn Uint256
        let (assert_res) = uint256_le(option_size_uint256, user_tokens_owned);
        assert assert_res = 1;
    }

    // Burn the user tokens
    IOptionToken.burn(option_token_address, user_address, option_size_uint256);

    if (option_side == TRADE_SIDE_LONG) {
        // User is long
        // When user was long there is a possibility, that the pool is short,
        // which means that pool has locked in some capital.
        // We assume pool is able to "expire" it's functions pretty quickly so the updates
        // of storage_vars has already happened.
        IERC20.transfer(
            contract_address=currency_address,
            recipient=user_address,
            amount=long_value_uint256,
        );
    } else {
        // User is short
        // User locked in capital (no locking happened from pool - no locked capital and similar
        // storage vars were updated).
        IERC20.transfer(
            contract_address=currency_address,
            recipient=user_address,
            amount=short_value_uint256,
        );
    }

    return ();
}
