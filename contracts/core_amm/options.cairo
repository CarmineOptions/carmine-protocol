%lang starknet

//
// @title Options handling module
// @notice Module that deals with minting, burning and expirying options for users.
//

// Functions related to option token minting, option accouting, ...


// @notice Adds option into the AMM. Requires all the option definition.
// @dev ATM this requires Proxy contract, but down the line it will be replaced by governance
//      voting.
// @param option_side: Either 0 or 1. 0 for long option and 1 for short.
// @param maturity: Maturity as unix timestamp.
// @param strike_price: Strike in terms of Math64x61. For example 3458764513820540928000 for strike
//      1500 USD (ie 1500*2**61 = 3458764513820540928000).
// @param quote_token_address: Address of quote token (USDC in case of ETH/USDC).
// @param base_token_address: Address of base token (ETH in case of ETH/USDC).
// @param option_type: 0 or 1. 0 for call option and 1 for put option.
// @param lptoken_address: Address of lp token. Ie identifier of liquidity pool that will be
//      providing liquidity for this option.
// @param option_token_address_: Address of option token. These token are later on minted when
//      users are getting into this position.
// @param initial_volatility: Initial volatility in terms of Math64x61. Ie 80% volatility is
//      inputted as 184467440737095516160.
// @return: Doesn't return anything. 
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
    // Assert that address hasn't been written yet

    with_attr error_message("Option Token has already been added") {
        let (opt_address) = get_option_token_address(
            lptoken_address, option_side, maturity, strike_price
        );
        assert opt_address = 0;
    }
    
    with_attr error_message("Given inputs for add_option function do not match the option token") {
        let (contract_option_type) = IOptionToken.option_type(option_token_address_);
        let (contract_strike) = IOptionToken.strike_price(option_token_address_);
        let (contract_maturity) = IOptionToken.maturity(option_token_address_);
        let (contract_option_side) = IOptionToken.side(option_token_address_);
        assert contract_strike = strike_price;
        assert contract_maturity = maturity;
        assert contract_option_type = option_type;
        assert contract_option_side = option_side;
    }
    
    // 2) Update following
    set_pool_volatility_separate(
        lptoken_address=lptoken_address,
        maturity=maturity,
        strike_price=strike_price,
        volatility=initial_volatility
    );
    append_to_available_options(
        option_side,
        maturity,
        strike_price,
        quote_token_address,
        base_token_address,
        option_type,
        lptoken_address
    );

    set_option_token_address(
        lptoken_address, option_side, maturity, strike_price, option_token_address_
    );

    return ();
}


// @notice Mints option token for user and "removes" capital from the user.
// @dev  User opens/increases its position (if user is long, it increases the size of its long,
//      if he/she is short, the short gets increased).
//      Switching position from long to short requires both mint_option_token and burn_option_token
//      functions to be called. This also changes internal state of the pool and realocates locked
//      capital/premia and fees between user and the pool for example how much capital is unlocked,
//      how much is locked,...
// @param lptoken_address: Address of lp token. Ie identifier of liquidity pool that will be
//      providing liquidity for this option.
// @param option_size: Size of option to be minted. In decimals of base token (ETH in case of
//      ETH/USDC). For example size 0.1 is inputted as 0.1 * 10**18.
// @param option_size_in_pool_currency: Same as option_size, just in the pool's currency
//      (each option is assigned to given pool). For example for PUT option this is in USDC.
//      This variable is used to lock in capital into the option. This means that
//      option_size_in_pool_currency might be tiny bit bigger than option_size in value, but not
//      smaller.
// @param option_side: Either 0 or 1. 0 for long option and 1 for short.
// @param option_type: 0 or 1. 0 for call option and 1 for put option.
// @param maturity: Maturity as unix timestamp.
// @param strike_price: Strike in terms of Math64x61. For example 3458764513820540928000 for strike
//      1500 USD (ie 1500*2**61 = 3458764513820540928000).
// @param premia_including_fees: What the user pays for the option or what the user gets
//      for the option in terms of premium. It's already adjusted for fees but not for locked
//      capital if that is required.
// @param underlying_price: Price of the underlying asset.
// @return: Doesn't return anything.
func mint_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_size: Int, // in base tokens (ETH in case of ETH/USDC)
    option_size_in_pool_currency: Uint256,
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
            );
        }

        with_attr error_message("Trade exceeds max allowed option size"){

            let (adjspd) = get_pool_volatility_adjustment_speed(lptoken_address=lptoken_address);
            assert_nn(adjspd);

            let (max_opt_perc) = get_max_option_size_percent_of_voladjspd();
            let max_opt_perc_math = Math64x61.fromFelt(max_opt_perc);
            const hundred = 230584300921369395200; // Math64x61.fromFelt(100);
            let ratio = Math64x61.div(max_opt_perc_math, hundred);

            let max_optsize_m64x61 = Math64x61.mul(ratio, adjspd);
            let max_optsize = toInt_balance(max_optsize_m64x61, option_token_address);
            
            assert_le(option_size_in_pool_currency.low, max_optsize);
        }
    }

    return ();
}


// @notice Mints LONG option token for user and "removes" capital from the user.
// @dev Not only mints the option token, but also transfers cash from user and update
//      internal state. Transfers premium from user to the pool and locks the pool's capital
//      to guarantee the buyers payment.
// @param lptoken_address: Address of lp token. Ie identifier of liquidity pool that will be
//      providing liquidity for this option.
// @param option_token_address:
// @param option_size: Size of option to be minted. In decimals of base token (ETH in case of
//      ETH/USDC). For example size 0.1 is inputted as 0.1 * 10**18.
// @param option_size_in_pool_currency: Same as option_size, just in the pool's currency
//      (each option is assigned to given pool). For example for PUT option this is in USDC.
//      This variable is used to lock in capital into the option. This means that
//      option_size_in_pool_currency might be tiny bit bigger than option_size in value, but not
//      smaller.
// @param premia_including_fees: What the user pays for the option or what the user gets
//      for the option in terms of premium. It's already adjusted for fees but not for locked
//      capital if that is required.
// @param option_type: 0 or 1. 0 for call option and 1 for put option.
// @param maturity: Maturity as unix timestamp.
// @param strike_price: Strike in terms of Math64x61. For example 3458764513820540928000 for strike
//      1500 USD (ie 1500*2**61 = 3458764513820540928000).
// @return: Doesn't return anything.
func _mint_option_token_long{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_token_address: Address,
    option_size: Int,
    option_size_in_pool_currency: Uint256,
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
        let quote_address = pool_definition.quote_token_address;

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

        // Move premia and fees from user to the pool
        with_attr error_message("Failed to convert premia_including_fees to Uint256 _mint_option_token_long") {
            let premia_including_fees_uint256 = toUint256_balance(premia_including_fees, currency_address);
        }
        with_attr error_message("Failed to convert option size to u256") {
            let option_size_uint256 = intToUint256(option_size);
        }
        local premia_including_fees_uint256_low = premia_including_fees_uint256.low;
        local option_size_in_pool_currency_low = option_size_in_pool_currency.low;

        TradeOpen.emit(
            caller=user_address,
            option_token=option_token_address,
            capital_transfered=premia_including_fees_uint256,
            option_tokens_minted=option_size_uint256,
        );

        // Pool is locking in capital only if there is no previous position to cover the user's long
        //      -> if pool does not have sufficient long to "pass down to user", it has to lock
        //           capital... option position has to be updated too!!!

        with_attr error_message("Failed to update lpool_balance in _mint_option_token_long") {
            // Increase lpool_balance by premia_including_fees -> this also increases unlocked capital
            // since only locked_capital storage_var exists
            let (current_balance) = get_lpool_balance(lptoken_address);
            let (new_balance: Uint256, carry: felt) = uint256_add(current_balance, premia_including_fees_uint256);
            assert carry = 0;
            // The nonnegativity of new_balance is checked inside of the set_lpool_balance
            set_lpool_balance(lptoken_address, new_balance);
        }

        // Update pool's position, lock capital... lpool_balance was already updated above
        let (current_long_position) = get_option_position(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price
        );
        let (current_short_position) = get_option_position(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price
        );
        let (current_locked_balance: Uint256) = get_pool_locked_capital(lptoken_address);

        with_attr error_message("Failed to convert amount in _mint_option_token_long") {
            // Get diffs to update everything
            let (decrease_long_by) = min(option_size, current_long_position);
            let increase_short_by: Int = option_size - decrease_long_by;
            let increase_short_by_uint256 = intToUint256(increase_short_by);
            let strike_price_uint256 = toUint256_balance(strike_price, quote_address);
            let (increase_locked_by: Uint256) = convert_amount_to_option_currency_from_base_uint256(
                increase_short_by_uint256,
                option_type,
                strike_price_uint256,
                base_address
            );
        }

        with_attr error_message("Failed to calculate new_locked_capital in _mint_option_token_long") {
            // New state
            let new_long_position = current_long_position - decrease_long_by;
            assert_nn(new_long_position);
            let new_short_position = current_short_position + increase_short_by;
            assert_nn(new_short_position); // might in theory overflow
            let (new_locked_capital: Uint256, carry_: felt) = uint256_add(current_locked_balance, increase_locked_by);
            assert carry_ = 0;
        }

        // Check that there is enough capital to be locked.
        with_attr error_message("Not enough unlocked capital in pool") {
            assert_uint256_le(new_locked_capital, new_balance);
        }

        with_attr error_message("Failed to update pool_locked_capital in _mint_option_token_long") {
            // Update the state
            set_option_position(lptoken_address, TRADE_SIDE_LONG, maturity, strike_price, new_long_position);
            set_option_position(lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price, new_short_position);
            set_pool_locked_capital(lptoken_address, new_locked_capital);
        }

        // Mint tokens
        with_attr error_message("Failed to mint option token in _mint_option_token_long") {
            IOptionToken.mint(option_token_address, user_address, option_size_uint256);
        }

        with_attr error_message(
            "Failed to transfer premia and fees _mint_option_token_long {currency_address}, {user_address}, {current_contract_address}, {premia_including_fees_uint256_low}, {option_size}, {option_size_in_pool_currency_low}"
        ) {
            IERC20.transferFrom(
                contract_address=currency_address,
                sender=user_address,
                recipient=current_contract_address,
                amount=premia_including_fees_uint256,
            );  // Whole tx will fail if there is not enough funds on users account
        }
    }

    return ();
}


// @notice Mints SHORT option token for user and "removes" capital from the user.
// @dev Not only mints the option token, but also transfers cash from user and update
//      internal state. Transfers (locked capital minus premium) from user to the pool to guarantee
//      pool's payoff.
// @param lptoken_address: Address of lp token. Ie identifier of liquidity pool that will be
//      providing liquidity for this option.
// @param option_token_address:
// @param option_size: Size of option to be minted. In decimals of base token (ETH in case of
//      ETH/USDC). For example size 0.1 is inputted as 0.1 * 10**18.
// @param option_size_in_pool_currency: Same as option_size, just in the pool's currency
//      (each option is assigned to given pool). For example for PUT option this is in USDC.
//      This variable is used to lock in capital into the option. This means that
//      option_size_in_pool_currency might be tiny bit bigger than option_size in value, but not
//      smaller.
// @param premia_including_fees: What the user pays for the option or what the user gets
//      for the option in terms of premium. It's already adjusted for fees but not for locked
//      capital if that is required.
// @param option_type: 0 or 1. 0 for call option and 1 for put option.
// @param maturity: Maturity as unix timestamp.
// @param strike_price: Strike in terms of Math64x61. For example 3458764513820540928000 for strike
//      1500 USD (ie 1500*2**61 = 3458764513820540928000).
// @return: Doesn't return anything.
func _mint_option_token_short{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_token_address: Address,
    option_size: Int,
    option_size_in_pool_currency: Uint256,
    premia_including_fees: Math64x61_,
    option_type: OptionType,
    maturity: Int,
    strike_price: Math64x61_
) {
    alloc_locals;

    with_attr error_message("_mint_option_token_short failed") {
        let (current_contract_address) = get_contract_address();
        let (user_address) = get_caller_address();
        let (currency_address) = get_underlying_token_address(lptoken_address);
        let (pool_definition) = get_pool_definition_from_lptoken_address(lptoken_address);
        let base_address = pool_definition.base_token_address;
        let quote_address = pool_definition.quote_token_address;

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

        let option_size_uint256 = intToUint256(option_size);
        let premia_including_fees_uint256 = toUint256_balance(premia_including_fees, currency_address);
        let (to_be_paid_by_user) = uint256_sub(option_size_in_pool_currency, premia_including_fees_uint256);

        let to_be_paid_by_user_low = to_be_paid_by_user.low;

        TradeOpen.emit(
            caller=user_address,
            option_token=option_token_address,
            capital_transfered=to_be_paid_by_user,
            option_tokens_minted=option_size_uint256,
        );

        // Decrease lpool_balance by premia_including_fees -> this also decreases unlocked capital
        // since only locked_capital storage_var exists
        with_attr error_message("Failed to adjust lpool_balance"){
            let (current_balance) = get_lpool_balance(lptoken_address);
            let (new_balance: Uint256) = uint256_sub(current_balance, premia_including_fees_uint256);
            set_lpool_balance(lptoken_address, new_balance);
        }

        // User is going short, hence user is locking in capital...
        //      if pool has short position -> unlock pool's capital
        // pools_position is in terms of base tokens (ETH in case of ETH/USD)...
        //      in same units is option_size
        // since user wants to go short, the pool can "sell off" its short... and unlock its capital

        // Update pool's short position
        let (pools_short_position) = get_option_position(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price
        );
        let (size_to_be_unlocked_in_base) = min(option_size, pools_short_position);
        let new_pools_short_position = pools_short_position - size_to_be_unlocked_in_base;
        set_option_position(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price, new_pools_short_position
        );

        // Update pool's long position
        let (pools_long_position) = get_option_position(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price
        );
        let size_to_increase_long_position = option_size - size_to_be_unlocked_in_base;
        let new_pools_long_position = pools_long_position + size_to_increase_long_position;
        assert_nn(new_pools_long_position);
        set_option_position(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price, new_pools_long_position
        );

        // Update the locked capital
        let size_to_be_unlocked_in_base_uint256 = intToUint256(size_to_be_unlocked_in_base);
        let strike_price_uint256 = toUint256_balance(strike_price, quote_address);
        let (size_to_be_unlocked) = convert_amount_to_option_currency_from_base_uint256(
            size_to_be_unlocked_in_base_uint256, option_type, strike_price_uint256, base_address
        );
        let (current_locked_balance: Uint256) = get_pool_locked_capital(lptoken_address);
        let (new_locked_balance: Uint256) = uint256_sub(current_locked_balance, size_to_be_unlocked);

        // Non negativity of the new_locked_balance is validated in set_pool_locked_capital
        set_pool_locked_capital(lptoken_address, new_locked_balance);

        // Mint tokens
        IOptionToken.mint(option_token_address, user_address, option_size_uint256);

        // Move (option_size minus (premia minus fees)) from user to the pool
        with_attr error_message("Failed to lock up enough capital, tried to transfer {to_be_paid_by_user_low} of {currency_address}") {
            IERC20.transferFrom(
                contract_address=currency_address,
                sender=user_address,
                recipient=current_contract_address,
                amount=to_be_paid_by_user,
            );
        }
    }

    return ();
}


// @notice Burns option token (closes position) for user and "sends" capital to the user.
// @dev User decreases its position (if user is long, it decreases the size of its long, if he/she
//      is short, the short gets decreased). Switching position from long to short requires both
//      mint_option_token and burn_option_token functions to be called. This also changes internal
//      state of the pool and realocates locked capital/premia and fees between user and the pool
//      for example how much capital is unlocked, how much is locked,...
// @param lptoken_address: Address of lp token. Ie identifier of liquidity pool that will be
//      providing liquidity for this option.
// @param option_size: Size of option to be minted. In decimals of base token (ETH in case of
//      ETH/USDC). For example size 0.1 is inputted as 0.1 * 10**18.
// @param option_size_in_pool_currency: Same as option_size, just in the pool's currency
//      (each option is assigned to given pool). For example for PUT option this is in USDC.
//      This variable is used to lock in capital into the option. This means that
//      option_size_in_pool_currency might be tiny bit bigger than option_size in value, but not
//      smaller.
// @param option_side: Either 0 or 1. 0 for long option and 1 for short.
// @param option_type: 0 or 1. 0 for call option and 1 for put option.
// @param maturity: Maturity as unix timestamp.
// @param strike_price: Strike in terms of Math64x61. For example 3458764513820540928000 for strike
//      1500 USD (ie 1500*2**61 = 3458764513820540928000).
// @param premia_including_fees: What the user gets for the option or what the user pays
//      for the option in terms of premium. It's already adjusted for fees but not for locked
//      capital if that is required.
// @param underlying_price: Price of the underlying asset.
// @return: Doesn't return anything.
func burn_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_size: Int,
    option_size_in_pool_currency: Uint256,
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

    local optsize_in_pc = option_size_in_pool_currency.low;
    local optsize = option_size;
    if (option_side == TRADE_SIDE_LONG) {
        with_attr error_message("unable to burn option token long optsize: {optsize}, optsize_in_pc: {optsize_in_pc}, strike: {strike_price}"){
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
        }
    } else {
        with_attr error_message("unable to burn option token short optsize: {optsize}, optsize_in_pc: {optsize_in_pc}, strike: {strike_price}"){
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
    }

    with_attr error_message("Trade exceeds max allowed option size"){

        let (adjspd) = get_pool_volatility_adjustment_speed(lptoken_address=lptoken_address);
        assert_nn(adjspd);

        let (max_opt_perc) = get_max_option_size_percent_of_voladjspd();
        let max_opt_perc_math = Math64x61.fromFelt(max_opt_perc);
        const hundred = 230584300921369395200; // Math64x61.fromFelt(100);
        let ratio = Math64x61.div(max_opt_perc_math, hundred);

        let max_optsize_m64x61 = Math64x61.mul(ratio, adjspd);
        let max_optsize = toInt_balance(max_optsize_m64x61, option_token_address);

        assert_le(option_size_in_pool_currency.low, max_optsize);
    }

    return ();
}


// @notice Burns LONG option token (closes position) for user and "sends" capital to the user.
// @dev Burns users tokens, sends capital to the user and updates internal state.
// @param lptoken_address: Address of lp token. Ie identifier of liquidity pool that will be
//      providing liquidity for this option.
// @param option_token_address: Address of the option token to be burned.
// @param option_size: Size of option to be minted. In decimals of base token (ETH in case of
//      ETH/USDC). For example size 0.1 is inputted as 0.1 * 10**18.
// @param option_size_in_pool_currency: Same as option_size, just in the pool's currency
//      (each option is assigned to given pool). For example for PUT option this is in USDC.
//      This variable is used to lock in capital into the option. This means that
//      option_size_in_pool_currency might be tiny bit bigger than option_size in value, but not
//      smaller.
// @param premia_including_fees: What the user gets for the option or what the user pays
//      for the option in terms of premium. It's already adjusted for fees but not for locked
//      capital if that is required.
// @param option_side: Either 0 or 1. 0 for long option and 1 for short.
// @param option_type: 0 or 1. 0 for call option and 1 for put option.
// @param maturity: Maturity as unix timestamp.
// @param strike_price: Strike in terms of Math64x61. For example 3458764513820540928000 for strike
//      1500 USD (ie 1500*2**61 = 3458764513820540928000).
// @return: Doesn't return anything.
func _burn_option_token_long{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_token_address: Address,
    option_size: Int,
    option_size_in_pool_currency: Uint256,
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

    let (user_address) = get_caller_address();
    let (currency_address) = get_underlying_token_address(lptoken_address);
    let (pool_definition) = get_pool_definition_from_lptoken_address(lptoken_address);
    let base_address = pool_definition.base_token_address;
    let quote_address = pool_definition.quote_token_address;

    let option_size_uint256 = intToUint256(option_size);
    let premia_including_fees_uint256 = toUint256_balance(premia_including_fees, currency_address);

    TradeClose.emit(
        caller=user_address,
        option_token=option_token_address,
        capital_transfered=premia_including_fees_uint256,
        option_tokens_burned=option_size_uint256,
    );

    // Decrease lpool_balance by premia_including_fees -> this also decreases unlocked capital
    // This decrease is happening because burning long is similar to minting short,
    // hence the payment.
    let (current_balance: Uint256) = get_lpool_balance(lptoken_address);
    let premia_including_fees_uint256: Uint256 = toUint256_balance(premia_including_fees, currency_address);
    let (new_balance: Uint256) = uint256_sub(current_balance, premia_including_fees_uint256);
    set_lpool_balance(lptoken_address, new_balance);

    let (pool_short_position) = get_option_position(
        lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price
    );
    let (pool_long_position) = get_option_position(
        lptoken_address, TRADE_SIDE_LONG, maturity, strike_price
    );

    if (pool_short_position == 0){
        // If pool is LONG:
        // Burn long increases pool's long (if pool was already long)
        //      -> The locked capital was locked by users and not pool
        //      -> do not decrease pool_locked_capital by the option_size_in_pool_currency
        let new_option_position = pool_long_position + option_size;
        assert_nn(new_option_position); // to check that it doesn't overflow
        set_option_position(
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

        let (current_locked_balance) = get_pool_locked_capital(lptoken_address);
        let (size_to_be_unlocked_in_base) = min(pool_short_position, option_size);

        let size_to_be_unlocked_in_base_uint256 = intToUint256(size_to_be_unlocked_in_base);
        let strike_price_uint256 = toUint256_balance(strike_price, quote_address);
        let (size_to_be_unlocked: Uint256) = convert_amount_to_option_currency_from_base_uint256(
            size_to_be_unlocked_in_base_uint256, option_type, strike_price_uint256, base_address
        );
        let (new_locked_balance: Uint256) = uint256_sub(current_locked_balance, size_to_be_unlocked);
        set_pool_locked_capital(lptoken_address, new_locked_balance);

        // Update pool's short position
        let new_pools_short_position = pool_short_position - size_to_be_unlocked_in_base;
        assert_nn(new_pools_short_position);
        set_option_position(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price, new_pools_short_position
        );

        // Update pool's long position
        let size_to_increase_long_position = option_size - size_to_be_unlocked_in_base;
        assert_nn(size_to_increase_long_position);
        let new_pools_long_position = pool_long_position + size_to_increase_long_position;
        assert_nn(new_pools_long_position);
        set_option_position(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price, new_pools_long_position
        );
    }

    // Burn the tokens
    IOptionToken.burn(option_token_address, user_address, option_size_uint256);
    
    IERC20.transfer(
        contract_address=currency_address,
        recipient=user_address,
        amount=premia_including_fees_uint256,
    );

    return ();
}


// @notice Burns SHORT option token (closes position) for user and "sends" capital to the user.
// @dev Burns users tokens, sends capital to the user and updates internal state.
// @param lptoken_address: Address of lp token. Ie identifier of liquidity pool that will be
//      providing liquidity for this option.
// @param option_token_address: Address of the option token to be burned.
// @param option_size: Size of option to be minted. In decimals of base token (ETH in case of
//      ETH/USDC). For example size 0.1 is inputted as 0.1 * 10**18.
// @param option_size_in_pool_currency: Same as option_size, just in the pool's currency
//      (each option is assigned to given pool). For example for PUT option this is in USDC.
//      This variable is used to lock in capital into the option. This means that
//      option_size_in_pool_currency might be tiny bit bigger than option_size in value, but not
//      smaller.
// @param premia_including_fees: What the user gets for the option or what the user pays
//      for the option in terms of premium. It's already adjusted for fees but not for locked
//      capital if that is required.
// @param option_side: Either 0 or 1. 0 for long option and 1 for short.
// @param option_type: 0 or 1. 0 for call option and 1 for put option.
// @param maturity: Maturity as unix timestamp.
// @param strike_price: Strike in terms of Math64x61. For example 3458764513820540928000 for strike
//      1500 USD (ie 1500*2**61 = 3458764513820540928000).
// @return: Doesn't return anything.
func _burn_option_token_short{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_token_address: Address,
    option_size: Int,
    option_size_in_pool_currency: Uint256,
    premia_including_fees: Math64x61_,
    option_side: OptionSide,
    option_type: OptionType,
    maturity: Int,
    strike_price: Math64x61_,
) {
    // option_side is the side of the token being closed

    alloc_locals;

    let (user_address) = get_caller_address();
    let (currency_address) = get_underlying_token_address(lptoken_address);
    let (pool_definition) = get_pool_definition_from_lptoken_address(lptoken_address);
    let base_address = pool_definition.base_token_address;
    let quote_address = pool_definition.quote_token_address;

    let premia_including_fees_uint256 = toUint256_balance(premia_including_fees, currency_address);
    let option_size_uint256 = intToUint256(option_size);

    let (total_user_payment) = uint256_sub(option_size_in_pool_currency, premia_including_fees_uint256);

    TradeClose.emit(
        caller=user_address,
        option_token=option_token_address,
        capital_transfered=total_user_payment,
        option_tokens_burned=option_size_uint256,
    );

    // Increase lpool_balance by premia_including_fees -> this also increases unlocked capital
    // This increase is happening because burning short is similar to minting long,
    // hence the payment.
    let (current_balance: Uint256) = get_lpool_balance(lptoken_address);
    let premia_including_fees_uint256: Uint256 = toUint256_balance(premia_including_fees, currency_address);
    let (new_balance: Uint256, carry: felt) = uint256_add(current_balance, premia_including_fees_uint256);
    assert carry = 0;
    set_lpool_balance(lptoken_address, new_balance);

    // Find out pools position... if it has short position = 0 -> it is long or at 0
    let (pool_short_position) = get_option_position(
        lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price
    );

    let (current_locked_capital_uint256: Uint256) = get_pool_locked_capital(lptoken_address);
    // FIXME: the inside of the if (not the else) should work for both cases
    //      -> validate and update for more simple code
    if (pool_short_position == 0) {
        // If pool is LONG
        // Burn decreases pool's long -> up to a size of the pool's long 
        //      -> if option_size_in_pool_currency > pool's long -> pool starts to accumulate
        //         the short and has to lock in it's own capital -> lock capital
        //      -> there might be a case, when there is not enough capital to be locked -> fail
        //         the transaction

        let (pool_long_position) = get_option_position(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price
        );

        let (decrease_long_position_by) = min(pool_long_position, option_size);
        let increase_short_position_by = option_size - decrease_long_position_by;
        assert_nn(increase_short_position_by);
        let new_long_position = pool_long_position - decrease_long_position_by;
        let new_short_position = pool_short_position + increase_short_position_by;
        assert_nn(new_long_position);
        assert_nn(new_short_position);
        

        // The increase_short_position_by and capital_to_be_locked might both be zero,
        // if the long position is sufficient.

        with_attr error_message("Unable to work with increase_short_position_by this big until Cairo 1.0 comes along"){
            assert_le_felt(increase_short_position_by, 2**127-1);
        }
        //let increase_short_position_by_uint256 = intToUint256(increase_short_position_by);
        let increase_short_position_by_uint256 = Uint256(increase_short_position_by, 0);
        let strike_price_uint256 = toUint256_balance(strike_price, quote_address);
        let (capital_to_be_locked: Uint256) = convert_amount_to_option_currency_from_base_uint256(
            increase_short_position_by_uint256,
            option_type,
            strike_price_uint256,
            base_address
        );

        let (new_locked_capital: Uint256, carry_: felt) = uint256_add(current_locked_capital_uint256, capital_to_be_locked);
        assert carry_ = 0;


        // Set the option positions
        set_option_position(
            lptoken_address, TRADE_SIDE_LONG, maturity, strike_price, new_long_position
        );
        set_option_position(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price, new_short_position
        );

        // Set the pool_locked_capital_.
        set_pool_locked_capital(lptoken_address, new_locked_capital);

        // Assert there is enough capital to be locked
        with_attr error_message("Not enough capital to be locked.") {
            assert_uint256_lt(new_locked_capital, new_balance);
        }

        tempvar syscall_ptr: felt* = syscall_ptr;
        tempvar pedersen_ptr: HashBuiltin* = pedersen_ptr;
    } else {
        // If pool is SHORT
        // Burn increases pool's short
        //      -> increase pool's locked capital by the option_size_in_pool_currency
        //      -> there might not be enough unlocked capital to be locked
        let (current_unlocked_capital_uint256: Uint256) = get_unlocked_capital(lptoken_address);

        // Update locked capital
        let (new_locked_capital: Uint256, carry: felt) = uint256_add(
            current_locked_capital_uint256, option_size_in_pool_currency
        );
        assert carry = 0;

        with_attr error_message("Not enough unlocked capital."){
            assert_uint256_le(option_size_in_pool_currency, current_unlocked_capital_uint256);
            assert_uint256_le(new_locked_capital, new_balance);
        }
        
        // checking that new_locked_capital is non negative is done in the set_pool_locked_capital
        set_pool_locked_capital(lptoken_address, new_locked_capital);

        // Update pools (short) position
        let new_pools_short_position = pool_short_position + option_size;
        assert_nn(new_pools_short_position);
        set_option_position(
            lptoken_address, TRADE_SIDE_SHORT, maturity, strike_price, new_pools_short_position
        );

        tempvar syscall_ptr: felt* = syscall_ptr;
        tempvar pedersen_ptr: HashBuiltin* = pedersen_ptr;
    }

    // Burn the tokens
    IOptionToken.burn(option_token_address, user_address, option_size_uint256);

    // User receives back its locked capital, pays premia and fees
    IERC20.transfer(
        contract_address=currency_address,
        recipient=user_address,
        amount=total_user_payment,
    );

    return ();
}


// @notice Expires option token for the user.
// @dev Not an external func, it is used through trade_settle.
// @param lptoken_address: Address of lp token. Ie identifier of liquidity pool that will be
//      providing liquidity for this option.
// @param option_type: 0 or 1. 0 for call option and 1 for put option.
// @param option_side: Either 0 or 1. 0 for long option and 1 for short.
// @param strike_price: Strike in terms of Math64x61. For example 3458764513820540928000 for strike
//      1500 USD (ie 1500*2**61 = 3458764513820540928000).
// @param terminal_price: Price at which the option get settled.
// @param option_size: Size of option to be minted. In decimals of base token (ETH in case of
//      ETH/USDC). For example size 0.1 is inputted as 0.1 * 10**18.
// @param maturity: Maturity as unix timestamp.
// @return: Doesn't return anything.
func expire_option_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_type: OptionType,
    option_side: OptionSide,
    strike_price: Math64x61_,
    terminal_price: Math64x61_,
    option_size: Int,
    maturity: Int,
) {
    // EXPIRES OPTIONS ONLY FOR USERS (OPTION TOKEN HOLDERS) NOT FOR POOL.
    // terminal price is price at which option is being settled

    alloc_locals;

    ReentrancyGuard.start();

    with_attr error_message("expire_option_token failed when getting option token address") {
        let (option_token_address) = get_option_token_address(
            lptoken_address=lptoken_address,
            option_side=option_side,
            maturity=maturity,
            strike_price=strike_price
        );

        let (base_token_address) = IOptionToken.base_token_address(option_token_address);
    }

    let (currency_address) = get_underlying_token_address(lptoken_address);

    // The option (underlying asset x maturity x option type x strike) has to be "expired"
    // (settled) on the pool's side in terms of locked capital. Ie check that SHORT position
    // has been settled, if pool is LONG then it did not lock capital and we can go on.
    let (current_pool_position) = get_option_position(
        lptoken_address,TRADE_SIDE_SHORT, maturity, strike_price
    );
    tempvar syscall_ptr: felt* = syscall_ptr;
    tempvar pedersen_ptr: HashBuiltin* = pedersen_ptr;
    tempvar range_check_ptr = range_check_ptr;
    if (current_pool_position != 0) {
        expire_option_token_for_pool(
            lptoken_address=lptoken_address,
            option_side=option_side,
            strike_price=strike_price,
            maturity=maturity,
        );
    }
    // Check that the pool's position was expired correctly
    let (current_pool_position_2) = get_option_position( // FIXME this is called twice in the happy case
        lptoken_address,TRADE_SIDE_SHORT, maturity, strike_price
    );
    with_attr error_message(
        "Pool hasn't released the locked capital for users -> call expire_option_token_for_pool to release it."
    ) {
        assert current_pool_position_2 = 0;
    }

    // Make sure that user owns the option tokens
    let (user_address) = get_caller_address();
    let (user_tokens_owned) = IOptionToken.balanceOf(
        contract_address=option_token_address, account=user_address
    );
    with_attr error_message("User doesn't own any tokens.") {
        assert_not_zero(user_tokens_owned.low);
    }

    // Make sure that the contract is ready to expire
    let (current_block_time) = get_block_timestamp();
    let is_ripe = is_le(maturity, current_block_time);
    with_attr error_message("Contract isn't ripe yet.") {
        assert is_ripe = 1;
    }

    // long_value and short_value are both in terms of locked capital
    with_attr error_message("expire_option_token failed converting option size to math64x61") {
        let option_size_m64x61 = fromInt_balance(option_size, base_token_address);
    }   
    
    with_attr error_message("expire_option_token failed when splitting option locked capital") {
        let (long_value, short_value) = split_option_locked_capital(
            option_type, option_side, option_size_m64x61, strike_price, terminal_price
        );
    }
    
    with_attr error_message("expire_option_token failed when converting value to uint") {
        let long_value_uint256 = toUint256_balance(long_value, currency_address);
        let short_value_uint256 = toUint256_balance(short_value, currency_address);
    }
    
    with_attr error_message("expire_option_token failed when converting option_size to uint") {
        let option_size_uint256 = intToUint256(option_size);
    }

    with_attr error_message("option_size is higher than tokens owned by user") {
        assert_uint256_le(option_size_uint256, user_tokens_owned);
    }

    // Burn the user tokens
    IOptionToken.burn(option_token_address, user_address, option_size_uint256);
    with_attr error_message("expire_option_token failed when transfering funds") {
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

            TradeSettle.emit(
                caller=user_address,
                option_token=option_token_address,
                capital_transfered=long_value_uint256,
                option_tokens_burned=option_size_uint256,
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

            TradeSettle.emit(
                caller=user_address,
                option_token=option_token_address,
                capital_transfered=short_value_uint256,
                option_tokens_burned=option_size_uint256,
            );
        }
    }
    ReentrancyGuard.end();
    return ();
}
