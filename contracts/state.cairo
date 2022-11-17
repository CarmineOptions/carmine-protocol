%lang starknet

// In this file live all storage_vars of the AMM and their getters and setters.
// No @external functions, the state should be manipulated from their respective component files (e.g. liquidity_pool, amm)

// lptoken_address serves also as an identifier of pool
@storage_var
func available_lptoken_addresses(order_i: Int) -> (lptoken_address: Address) {
}


// FIXME: typo in lptoken_addres - missing "s"
// FIXME: rename this to lptoken_address_for_given_pool
@storage_var
func lptoken_addr_for_given_pooled_token(
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType
) -> (
    lptoken_addres: Address
) {
    // Where quote is USDC in case of ETH/USDC, base token is ETH in case of ETH/USDC
    // and option_type is either CALL or PUT (constants.OPTION_CALL or constants.OPTION_PUT).
    // lptoken_address serves throughout the liquidity_pool.cairo as id of the given pool.
}


// This is inverse to lptoken_addr_for_given_pooled_token
@storage_var
func pool_definition_from_lptoken_address(lptoken_addres: Address) -> (pool: Pool) {
}


// Option type that this pool corresponds to.
@storage_var
func option_type_(lptoken_address: Address) -> (option_type: OptionType) {
}


// Address of the underlying token (for example address of ETH or USD or...).
// Will return base/quote according to option_type
@storage_var
func underlying_token_address(lptoken_address: Address) -> (res: Address) {
}


// Stores current value of volatility for given pool (option type) and maturity.
@storage_var
func pool_volatility(lptoken_address: Address, maturity: Int) -> (volatility: Math64x61_) {
}


// List of available options (mapping from 1 to n to available strike x maturity,
// for n+1 returns zeros). STARTS INDEXING AT 0.
@storage_var
func available_options(lptoken_address: Address, order_i: Int) -> (Option) {
}


// Maping from option params to option address
@storage_var
func option_token_address(
    lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Math64x61_
) -> (res: Address) {
}


// Mapping from option params to pool's position
// Options held by the pool do not get their option tokens, which is why this storage_var exists.
@storage_var
func option_position(
    lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Math64x61_
) -> (res: Math64x61_) {
}


//migration only, to convert m64x61 lpool_balance to Uint256
@external
func migrate_lpool_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(lptoken_address: Address) {
    let (currval: Math64x61_) = lpool_balance.read(lptoken_address);
    let (lpool_underlying_token: Address) = underlying_token_address.read(lptoken_address);
    let newval: Uint256 = toUint256_balance(currval, lpool_underlying_token);
    set_lpool_balance(lptoken_address, newval);
    return ();
}


// total balance of underlying in the pool (owned by the pool)
// available balance for withdraw will be computed on-demand since
// compute is cheap, storage is expensive on StarkNet currently
// DEPRECATED
@storage_var
func lpool_balance(lptoken_address: Address) -> (res: Math64x61_) {
}

// we must rename the storage var during the migration, because otherwise Starknet would be angry that we are writing a struct
@storage_var
func lpool_balance_(lptoken_address: Address) -> (res: Uint256) {
}


// Locked capital owned by the pool... above is lpool_balance describing total capital owned
// by the pool. Ie lpool_balance = pool_locked_capital + pool's unlocked capital
// Note: capital locked by users is not accounted for here.
    // Simple example:
    // - start pool with no position
    // - user sells option (user locks capital), pool pays premia and does not lock capital
    // - there is more "IERC20.balanceOf" in the pool than "pool's locked capital + unlocked capital"
// DEPRECATED
@storage_var
func pool_locked_capital(lptoken_address: Address) -> (res: Math64x61_) {
}

@storage_var
func pool_locked_capital_(lptoken_address: Address) -> (res: Uint256) {
}

//migration only, to convert m64x61 lpool_balance to Uint256
@external
func migrate_pool_locked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(lptoken_address: Address) {
    let (currval: Math64x61_) = pool_locked_capital.read(lptoken_address);
    let (lpool_underlying_token: Address) = underlying_token_address.read(lptoken_address);
    let newval: Uint256 = toUint256_balance(currval, lpool_underlying_token);
    set_pool_locked_capital(lptoken_address, newval);
    return ();
}


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// storage_var handlers and helpers
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


@view
func get_available_lptoken_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    order_i: Int
) -> (lptoken_address: Address) {
    let (lptoken_address) = available_lptoken_addresses.read(order_i);
    return (lptoken_address,);
}


func set_available_lptoken_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    order_i: Int, lptoken_address: Address
) -> () {
    available_lptoken_addresses.write(order_i, lptoken_address);
    return ();
}


@view
func get_lpool_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (res: Uint256) {
    let (balance) = lpool_balance_.read(lptoken_address);
    return (balance,);
}


func set_lpool_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, balance: Uint256
) -> () {
    assert_uint256_le(Uint256(0, 0), balance);
    lpool_balance_.write(lptoken_address, balance);
    return ();
}


@view
func get_pool_locked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (res: Uint256) {
    let (locked_capital) = pool_locked_capital_.read(lptoken_address);
    return (locked_capital,);
}

func set_pool_locked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, balance: Uint256
) -> () {
    assert_uint256_le(Uint256(0, 0), balance);
    pool_locked_capital_.write(lptoken_address, balance);
    return ();
}


@view
func get_available_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, order_i: Int
) -> (
    option: Option
) {
    alloc_locals;
    let (option) = available_options.read(lptoken_address, order_i);
    return (option,);
}


@view
func get_pools_option_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Math64x61_
) -> (
    res: Math64x61_
) {
    let (position) = option_position.read(lptoken_address, option_side, maturity, strike_price);
    return (position,);
}


@view
func get_lptoken_address_for_given_option{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType
) -> (
    lptoken_address: Address
) {
    alloc_locals;
    let (lptoken_addres) = lptoken_addr_for_given_pooled_token.read(
        quote_token_address, base_token_address, option_type
    );

    with_attr error_message("Specified pool does not exist"){
        assert_not_zero(lptoken_addres);
    }

    return (lptoken_address=lptoken_addres);
}


@view
func get_pool_definition_from_lptoken_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_addres: Address
) -> (
    pool: Pool
) {
    alloc_locals;
    let (pool) = pool_definition_from_lptoken_address.read(lptoken_addres);

    with_attr error_message(
        "Definition of pool (quote address) for lptoken {lptoken_addres} does not exist"
    ){
        assert_not_zero(pool.quote_token_address);
    }

    with_attr error_message(
        "Definition of pool (base address) for lptoken {lptoken_addres} does not exist"
    ){
        assert_not_zero(pool.base_token_address);
    }

    with_attr error_message(
        "Definition of pool (option type) for lptoken {lptoken_addres} is not correct"
    ){
        assert (pool.option_type - OPTION_CALL) * (pool.option_type - OPTION_PUT) = 0;
    }

    return (pool=pool);
}


func set_pool_definition_from_lptoken_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_addres: Address,
    pool: Pool,
) {
    // will be deleted once we are migrated
    alloc_locals;
    pool_definition_from_lptoken_address.write(lptoken_addres, pool);
    return ();
}


@view
func get_option_type{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (option_type: OptionType) {
    let (option_type) = option_type_.read(lptoken_address);
    return (option_type,);
}


@view
func get_pool_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, maturity: Int
) -> (pool_volatility: Math64x61_) {
    let (pool_volatility_) = pool_volatility.read(lptoken_address, maturity);
    return (pool_volatility_,);
}


@view
func get_underlying_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (underlying_token_address_: Address) {
    let (underlying_token_address_) = underlying_token_address.read(lptoken_address);

    with_attr error_message(
        "Failed getting underlying token address inget_underlying_token_address, address is zero"
    ){
        assert_not_zero(underlying_token_address_);
    }
    return (underlying_token_address_,);
}


func set_pool_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, maturity: Int, volatility: Math64x61_
) {
    // volatility has to be above 1 (in terms of Math64x61.FRACT_PART units...
    // ie volatility = 1 is very very close to 0 and 100% volatility would be
    // volatility=Math64x61.FRACT_PART)

    alloc_locals;

    assert_nn_le(volatility, VOLATILITY_UPPER_BOUND - 1);
    assert_nn_le(VOLATILITY_LOWER_BOUND, volatility);
    pool_volatility.write(lptoken_address, maturity, volatility);
    return ();
}


@view
func get_unlocked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (unlocked_capital: Math64x61_) {
    alloc_locals;
    // Returns capital that is unlocked for immediate extraction/use.
    // This is for example ETH in case of ETH/USD CALL options.

    // Capital locked by the pool
    let (locked_capital) = pool_locked_capital.read(lptoken_address);

    // Get capital that is sum of unlocked (available) and locked capital.
    let (contract_balance_uint256: Uint256) = get_lpool_balance(lptoken_address);
    let (lpool_underlying_token: Address) = underlying_token_address.read(lptoken_address);
    let contract_balance: Math64x61_ = fromUint256_balance(contract_balance_uint256, lpool_underlying_token);

    let unlocked_capital = Math64x61.sub(contract_balance, locked_capital);
    return (unlocked_capital = unlocked_capital);
}


@view
func get_option_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Math64x61_
) -> (option_token_address: Address) {
    let (option_token_addr) = option_token_address.read(
        lptoken_address, option_side, maturity, strike_price
    );
    return (option_token_address=option_token_addr);
}


@view
func get_available_options_usable_index{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address,
    starting_index: Int
) -> (usable_index: Int) {
    // Returns lowest index that does not contain any specified option.

    alloc_locals;

    let (option) = available_options.read(lptoken_address, starting_index);

    // Because of how the defined options are stored we have to verify that we have not run
    // at the end of the stored values. The end is with "empty" Option.
    let option_sum = option.maturity + option.strike_price;
    if (option_sum == 0) {
        return (usable_index = starting_index);
    }

    let (usable_index) = get_available_options_usable_index(lptoken_address, starting_index + 1);

    return (usable_index = usable_index);
}


@view
func get_available_lptoken_addresses_usable_index{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    starting_index: Int
) -> (usable_index: Int) {
    // Returns lowest index that does not contain any specified lptoken_address.

    alloc_locals;

    let (lptoken_address) = get_available_lptoken_addresses(starting_index);

    if (lptoken_address == 0) {
        return (usable_index = starting_index);
    }

    let (usable_index) = get_available_lptoken_addresses_usable_index(starting_index + 1);

    return (usable_index = usable_index);
}


func _get_option_info{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address,
    option_side: OptionSide,
    strike_price: Math64x61_,
    maturity: Int,
    starting_index: felt,
) -> (option: Option) {
    // Returns Option (struct) information.

    alloc_locals;

    let (option_) = available_options.read(lptoken_address, starting_index);


    // Verify that we have not run at the end of the stored values. The end is with "empty" Option.

    with_attr error_message("Specified option is not available"){
        let option_sum = option_.maturity + option_.strike_price;
        assert_not_zero(option_sum);
    }

    if (option_.option_side == option_side) {
        if (option_.strike_price == strike_price) {
            if (option_.maturity == maturity) {
                return (option=option_);
            }
        }
    }

    let (option) = _get_option_info(
        lptoken_address=lptoken_address,
        option_side=option_side,
        strike_price=strike_price,
        maturity=maturity,
        starting_index=starting_index+1
    );

    return (option = option);
}


func append_to_available_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_side: OptionSide,
    maturity: Int,
    strike_price: Math64x61_,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    lptoken_address: Address
) {
    alloc_locals;
    let new_option = Option(
        option_side=option_side,
        maturity=maturity,
        strike_price=strike_price,
        quote_token_address=quote_token_address,
        base_token_address=base_token_address,
        option_type=option_type
    );

    let (usable_index) = get_available_options_usable_index(lptoken_address, 0);

    available_options.write(lptoken_address, usable_index, new_option);

    return ();
}


// inefficiency and wastefulness of this functions doesn't matter, since it will be axed before going to mainnet.
// used only in removal of an option, which is something that will never happen
func remove_and_shift_available_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    index: felt
) {

    // Write zero option in provided index
    let zero_option = Option (0,0,0,0,0,0);
    available_options.write(lptoken_address, index, zero_option);
    shift_available_options(lptoken_address, index);

    return ();
}

func shift_available_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    index: felt
) {
    alloc_locals;

    // Assert that provided index stores zero option
    let (old_option) = available_options.read(lptoken_address, index);
    let old_option_sum = old_option.strike_price + old_option.maturity;
    assert old_option_sum = 0;

    // Read option on next index and assert that it is not zero option
    // since that would mean that we're at the end of list 
    let (next_option) = available_options.read(lptoken_address, index + 1);
    let next_option_sum = next_option.strike_price + next_option.maturity;
    if (next_option_sum == 0) {
        return();
    }

    // Assign next_option to current index and zero_option to next_index
    let zero_option = Option(0, 0, 0, 0, 0, 0);
    available_options.write(lptoken_address, index, next_option);
    available_options.write(lptoken_address, index + 1, zero_option);

    // Continue to next index
    shift_available_options(lptoken_address, index + 1);

    return ();
}