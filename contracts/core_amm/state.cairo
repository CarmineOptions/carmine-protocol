%lang starknet


//
// @title Internal state module
// @notice In this file live all storage_vars of the AMM and their getters and setters.
//      All code that changes state of the AMM is in this file.

// @notice Stores all the lptoken addresses
// @dev Stores the balances of each pot
// @param order_i: from 0 to n, used as a key to get to a given address
// @return lptoken_address: Address of given lp token. Which also serves as identifier
//      for given pool.
@storage_var
func available_lptoken_addresses(order_i: Int) -> (lptoken_address: Address) {
}


// FIXME: typo in lptoken_addres - missing "s"
// FIXME: rename this to lptoken_address_for_given_pool
// @notice Stores lp token addresses with access based on pool specification.
// @dev Stores lp token addresses with keys based on quote and base token addresses and option type
// @param quote_token_address: address of quote token (USDC in case of ETH/USDC)
// @param base_token_address: address of base token (ETH in case of ETH/USDC)
// @param option_type: 0 for call option pool and 1 for put
// @return lptoken_address: Address of given lp token. Which also serves as identifier
//      for given pool.
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


// @notice For given lp token stores the information about the definition of the pool
// @param lptoken_addres: Address of given lp token. Which also serves as identifier
//      for given pool.
// @return Returns Pool which is a struct of base token address, quote token address and option
//      type.
@storage_var
func pool_definition_from_lptoken_address(lptoken_addres: Address) -> (pool: Pool) {
}


// @notice For given lp token stores the information about what option type is traded in given pool
// @param lptoken_addres: Address of given lp token. Which also serves as identifier
//      for given pool.
// @return Returns option type (call or put) for given pool.
@storage_var
func option_type_(lptoken_address: Address) -> (option_type: OptionType) {
}


// @notice Stores address of the underlying token for given pool. Ie in which currency does given
//      pool operate. For example ETH/USDC PUT pool works with USDC and ETH/USDC CALL pool works
//      with ETH.
// @param lptoken_addres: Address of given lp token. Which also serves as identifier
//      for given pool.
// @return Returns address of the token that the pool operates in.
@storage_var
func underlying_token_address(lptoken_address: Address) -> (res: Address) {
}


// @notice Stores current value of volatility for given pool (option type) and maturity.
// @dev WILL BE DEPRECATED - this will be removed with next upgrade of testnet and
//      is not used at all if freshly deployed
// @param lptoken_addres: identifying to which pool this volatility belongs to
// @param maturity: identifying to which maturity this volatility belongs to (unix timestamp)
// @return Returns volatility. Volatility in % and in Math64x61.
//      So for example 184467440737095516160 is 80% volatility (184467440737095516160 / 2**61 = 80)
@storage_var
func pool_volatility(lptoken_address: Address, maturity: Int) -> (volatility: Math64x61_) {
}


// @notice Stores current value of volatility for given pool (option type), maturity and strike.
// @dev In past versions of testnet we were using same volatility for given maturity and
//      option type.
// @param lptoken_addres: identifying to which pool this volatility belongs to
// @param maturity: identifying to which maturity this volatility belongs to (unix timestamp)
// @param strike_price: identifying to which maturity this volatility belongs to (in Math64x61
//      so for example 3458764513820540928000 is strike price 1500 - 3458764513820540928000 /2**61)
// @return Returns volatility. Volatility in % and in Math64x61.
//      So for example 184467440737095516160 is 80% volatility (184467440737095516160 / 2**61 = 80)
@storage_var
func pool_volatility_separate(lptoken_address: Address, maturity: Int, strike_price: Math64x61_) -> (volatility: Math64x61_) {
}


// @notice List of available options (mapping from 1 to n to available strike x maturity,
//      for n+1 returns zeros). STARTS INDEXING AT 0.
// @param lptoken_address: id of given pool (address of given pool's LP token).
// @param order_i: from 0 to N. Just an index for getting the Option out. (N+1th element is all zeros).
// @return Returns Option struct. Which contains option_side, maturity, strike_price,
//      quote_token_address, base_token_address, option_type.
@storage_var
func available_options(lptoken_address: Address, order_i: Int) -> (Option) {
}


// @notice Maping from option params to option address.
// @param lptoken_addres: identifying to which pool this volatility belongs to
// @param option_side: 0 for long, 1 for short
// @param maturity: identifying to which maturity this volatility belongs to (unix timestamp)
// @param strike_price: identifying to which maturity this volatility belongs to (in Math64x61
//      so for example 3458764513820540928000 is strike price 1500 - 3458764513820540928000 /2**61)
// @return Returns address of given option's token.
@storage_var
func option_token_address(
    lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Math64x61_
) -> (res: Address) {
}

@storage_var
func max_lpool_balance(pooled_token_addr: Address) -> (res: Uint256) {
}

// Max option size per user as percentage of volatility adjustment speed
@storage_var
func max_option_size_percent_of_voladjspd() -> (res: Int) {
}

// @notice Mapping from option params to pool's position. Options held by the pool do not get their
//      option tokens, which is why this storage_var exists.
// @dev Notice the underscore at the end of the name. That is there because there was a migration
// @param lptoken_addres: identifying to which pool this volatility belongs to
// @param option_side: 0 for long, 1 for short
// @param maturity: identifying to which maturity this volatility belongs to (unix timestamp)
// @param strike_price: identifying to which maturity this volatility belongs to (in Math64x61
//      so for example 3458764513820540928000 is strike price 1500 - 3458764513820540928000 /2**61)
// @return Returns the position of pool in a given option. Is returned as Int, which means that if
//      the pool has position 1.1 size in ETH/USDC then the returned number is 1.1*10**18
@storage_var
func option_position_(
    lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Int
) -> (res: Int) {
}


// @notice Stores total balance of underlying in the pool (owned by the pool).
// @dev Notice the underscore at the end of the name. That is there because there was a migration
// @param lp_token_address: Identifier of given pool.
// @return Returns total balance of underlying in the pool (owned by the pool).
@storage_var
func lpool_balance_(lptoken_address: Address) -> (res: Uint256) {
}


// @notice Stores amount of locked capital owned by the pool.
//      (Total capital is in lpool_balance_)
//      lpool_balance = pool_locked_capital + pool's unlocked capital
//      Capital locked by users is not accounted for here.
//      Simple example:
//      - start pool with no position
//      - user sells option (user locks capital), pool pays premia and does not lock capital
//      - there is more "IERC20.balanceOf" in the pool than "pool's locked capital + unlocked capital"
// @dev Notice the underscore at the end of the name. That is there because there was a migration
// @param lp_token_address: Identifier of given pool.
// @return Returns amount of locked capital owned by the pool.
@storage_var
func pool_locked_capital_(lptoken_address: Address) -> (res: Uint256) {
}


// @notice Used in volatility calculation. Updated by governance roughly according to pool size.
@storage_var
func pool_volatility_adjustment_speed(lptoken_address: Address) -> (res: Math64x61_) {
}


// @notice is trading halted? If yes, then status = 1.
@storage_var
func trading_halted() -> (status: Bool) {
}


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// storage_var handlers and helpers
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


// @notice Reads lptoken address at given index. Useful for e.g. retrieving all lptokens.
// @dev Misleadingly named, should be get_lptoken_addresses since inclusion
//      here only means that the lpool exists.
@view
func get_available_lptoken_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    order_i: Int
) -> (lptoken_address: Address) {
    let (lptoken_address) = available_lptoken_addresses.read(order_i);
    return (lptoken_address,);
}


// @notice Writes lptoken address at given index. Used by add_lptoken
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
    let (option) = available_options.read(lptoken_address, order_i);
    return (option,);
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


func set_lptoken_address_for_given_option{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    lptoken_address: Address
) {
    with_attr error_message("One of the input values is zero in set_lptoken_address_for_given_option"){
        assert_not_zero(quote_token_address);
        assert_not_zero(base_token_address);
        assert_not_zero(lptoken_address);
    }
    with_attr error_message(
        "Unknown option_type: {option_type}, ie option_type is neither a PUT or CALL in set_lptoken_address_for_given_option"
    ){
        assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;
    }

    lptoken_addr_for_given_pooled_token.write(
        quote_token_address, base_token_address, option_type, lptoken_address
    );

    return ();
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
    lptoken_address: Address,
    pool: Pool,
) {
    alloc_locals;
    fail_if_existing_pool_definition_from_lptoken_address(lptoken_address);
    pool_definition_from_lptoken_address.write(lptoken_address, pool);
    return ();
}


func fail_if_existing_pool_definition_from_lptoken_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_addres: Address
) {
    // This function is here, because we need to check if given token has been already used or not,
    // but getters are failing for "not used" since they don't find any token.

    alloc_locals;

    let (pool) = pool_definition_from_lptoken_address.read(lptoken_addres);
    with_attr error_message("Given lptoken has already been registered"){
        assert pool.quote_token_address = 0;
        assert pool.base_token_address = 0;
        assert pool.option_type = 0;
    }

    return ();
}


@view
func get_option_type{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (option_type: OptionType) {
    let (option_type) = option_type_.read(lptoken_address);
    return (option_type,);
}


func set_option_type{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_type: OptionType
) {
    with_attr error_message(
        "Definition of pool (option type) for set_option_type is incorrect"
    ){
        assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;
    }

    option_type_.write(lptoken_address, option_type);
    return ();
}


// @notice Returns pool volatility for maturity-lptoken pair.
//      Only applicable if SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES = 0.
//      Otherwise, use get_pool_volatility_separate. 
@view
func get_pool_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, maturity: Int
) -> (pool_volatility: Math64x61_) {
    assert SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES = 0;
    let (pool_volatility_) = pool_volatility.read(lptoken_address, maturity);
    return (pool_volatility_,);
}

// @notice Returns pool volatility for maturity-lptoken-strike_price triple.
// @dev This @view function sometimes writes to storage if the migration to pool volatilities
//      for different strike prices is in progress. This is done to ensure a seamless migration.
//      View function annotations are also currently not enforced by Starknet.
//      There won't be writes from this function on mainnet.
@view
func get_pool_volatility_separate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, maturity: Int, strike_price: Math64x61_
) -> (pool_volatility: Math64x61_) {
    alloc_locals;

    assert SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES = 1;
    let (pool_volatility_) = pool_volatility_separate.read(lptoken_address, maturity, strike_price);
    if (pool_volatility_ == 0){
        // this is here only to ensure a seamless migration on testnet and will be removed on mainnet
        let (main_pool_vol) = pool_volatility.read(lptoken_address, maturity);
        set_pool_volatility_separate(lptoken_address, maturity, strike_price, main_pool_vol);
        return (main_pool_vol,);
    }
    return (pool_volatility_,);
}


// @notice Automatically retrieves correct pool vol according to SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES flag
// @dev Eliminates branching, local allocations and revoked references in code elsewhere.
@view
func get_pool_volatility_auto{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, maturity: Int, strike_price: Math64x61_
) -> (pool_volatility: Math64x61_) {
    if (SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES == 1){
        return get_pool_volatility_separate(lptoken_address, maturity, strike_price);
    }else{
        return get_pool_volatility(lptoken_address, maturity);
    }
}

// @notice Returns the current maximum total balance of the pooled token. This is across all pools
//      that pool a certain asset, so there is one limit for all USDC pools for example.
@view
func get_max_lpool_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: Address) -> (max_balance: Uint256) {
        let(maxbal) = max_lpool_balance.read(pooled_token_addr);
        return (maxbal, );
}

// @notice Directly sets max balance of pooled token across all pools.
// @dev External here is just to make sure testnet migration can go through correctly. Will be deprecated later
@external
func set_max_lpool_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: Address, max_lpool_bal: Uint256) {

        with_attr error_message("Max lpool balance can be set only by admin"){
            Proxy.assert_only_admin();
        }
    
        with_attr error_message("max lpool balance can't be negative") {
            assert_uint256_le(Uint256(0, 0), max_lpool_bal);
        }
        max_lpool_balance.write(pooled_token_addr, max_lpool_bal);
        return ();
}


// @notice Sets maximum total option size as a percentage of volatility adjustment speed.
@external
func set_max_option_size_percent_of_voladjspd{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    max_opt_size_as_perc_of_vol_adjspd: Int
){
    with_attr error_message("Max opt size perc can be set only by admin"){
        Proxy.assert_only_admin();
    }
    with_attr error_message("Max opt size perc can't be negative") {
        assert_nn(max_opt_size_as_perc_of_vol_adjspd);
    }

    max_option_size_percent_of_voladjspd.write(max_opt_size_as_perc_of_vol_adjspd);
    
    return ();
}

@view
func get_max_option_size_percent_of_voladjspd{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: Int){
    let (res) = max_option_size_percent_of_voladjspd.read();
    return (res, );
}


// @notice Returns the token that's underlying the given liquidity pool.
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


func set_underlying_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    underlying_token_address_: Address
) {
    with_attr error_message(
        "Failed set_underlying_token_address, one of the addresses is zero"
    ){
        assert_not_zero(lptoken_address);
        assert_not_zero(underlying_token_address_);
    }

    underlying_token_address.write(lptoken_address, underlying_token_address_);

    return ();
}


// @notice Sets pool volatility for maturity-lptoken pair.
//      Only applicable if SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES = 0.
//      Otherwise, use get_pool_volatility_separate.
func set_pool_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, maturity: Int, volatility: Math64x61_
) {
    // volatility has to be above 1 (in terms of Math64x61.FRACT_PART units...
    // ie volatility = 1 is very very close to 0 and 100% volatility would be
    // volatility=Math64x61.FRACT_PART)

    alloc_locals;
    with_attr error_message("tried to set pool volatility, but volatility is per-strike"){
        assert SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES = 0;
    }
    assert_nn_le(volatility, VOLATILITY_UPPER_BOUND - 1);
    assert_nn_le(VOLATILITY_LOWER_BOUND, volatility);
    pool_volatility.write(lptoken_address, maturity, volatility);
    return ();
}


// @notice Sets pool volatility for maturity-lptoken-strike triple.
//      Only applicable if SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES = 1.
func set_pool_volatility_separate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, maturity: Int, strike_price: Math64x61_, volatility: Math64x61_
) {
    // volatility has to be above 1 (in terms of Math64x61.FRACT_PART units...
    // ie volatility = 1 is very very close to 0 and 100% volatility would be
    // volatility=Math64x61.FRACT_PART)
    alloc_locals;
    assert SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES = 1;

    assert_nn_le(volatility, VOLATILITY_UPPER_BOUND - 1);
    assert_nn_le(VOLATILITY_LOWER_BOUND, volatility);
    pool_volatility_separate.write(lptoken_address, maturity, strike_price, volatility);
    return ();
}


func set_option_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Math64x61_, position: Int
) {
    with_attr error_message("Unable to set option position {lptoken_address} {maturity} {strike_price} {position}"){
        assert_nn_le(0, strike_price);
        assert_nn_le(0, position);
        option_position_.write(lptoken_address, option_side, maturity, strike_price, position);
    }
    return ();
}


// @notice Returns capital that is unlocked for immediate extraction/use.
//      This is for example ETH in case of ETH/USD CALL options.
// @dev Computed as contract_balance - locked_capital
@view
func get_unlocked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (unlocked_capital: Uint256) {
    alloc_locals;

    // Capital locked by the pool
    let (locked_capital: Uint256) = get_pool_locked_capital(lptoken_address);

    // Get capital that is sum of unlocked (available) and locked capital.
    let (contract_balance: Uint256) = get_lpool_balance(lptoken_address);

    let (unlocked_capital: Uint256) = uint256_sub(contract_balance, locked_capital);

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


func set_option_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_side: OptionSide,
    maturity: Int,
    strike_price: Math64x61_,
    option_token_address_: Address
) {
    alloc_locals;

    with_attr error_message("Unable to set option token address {lptoken_address} {option_side} {maturity} {strike_price} {option_token_address_}"){
        assert_not_zero(lptoken_address);
        assert (option_side - TRADE_SIDE_LONG) * (option_side - TRADE_SIDE_SHORT) = 0;
        assert_nn_le(0, maturity);
        assert_nn_le(0, strike_price);
        assert_not_zero(option_token_address_);

        option_token_address.write(
            lptoken_address, option_side, maturity, strike_price, option_token_address_
        );
    }
    return ();

}


// @notice Returns the given liqpool's position in a given option
// @return option_position: felt. Has same amount of decimals as base token.
@view
func get_option_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Math64x61_
) -> (option_position: Int) {
    let (opt_pos) = option_position_.read(
        lptoken_address, option_side, maturity, strike_price
    );
    return (option_position=opt_pos);
}


// @notice Returns the first free option index for the given lptoken address.
// @dev Returns lowest index that does not contain any specified option (only zeros).
@view
func get_available_options_usable_index{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address,
    starting_index: Int
) -> (usable_index: Int) {

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


// @notice Returns lowest index that does not contain any specified lptoken_address.
@view
func get_available_lptoken_addresses_usable_index{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    starting_index: Int
) -> (usable_index: Int) {

    alloc_locals;

    let (lptoken_address) = get_available_lptoken_addresses(starting_index);

    if (lptoken_address == 0) {
        return (usable_index = starting_index);
    }

    let (usable_index) = get_available_lptoken_addresses_usable_index(starting_index + 1);

    return (usable_index = usable_index);
}


// @notice Returns trading halt status. 1 = halted, 0 = not halted.
@view
func get_trading_halt{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() -> (res: Bool) {
    let (res) = trading_halted.read();
    return (res,);
}


@external
func set_trading_halt{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    new_status: Bool
) -> () {
    alloc_locals;
    let (caller_addr) = get_caller_address();
    local syscall_ptr: felt* = syscall_ptr;
    let (can_halt) = can_halt_trading(caller_addr);
    with_attr error_message("Only emergency admins can halt trading."){
        assert can_halt = 1;
    }
    assert_nn(new_status);
    assert_le(new_status, 1);
    trading_halted.write(new_status);
    return ();
}


func can_halt_trading{range_check_ptr}(account_address: felt) -> (res: Bool) {
    if (account_address == 0x0583a9d956d65628f806386ab5b12dccd74236a3c6b930ded9cf3c54efc722a1) {
        return (res = TRUE); // Ondra
    }
    if (account_address == 0x06717eaf502baac2b6b2c6ee3ac39b34a52e726a73905ed586e757158270a0af) {
        return (res = TRUE); // Andrej
    }
    if (account_address == 0x0011d341c6e841426448ff39aa443a6dbb428914e05ba2259463c18308b86233) {
        return (res = TRUE); // Marek
    }
    return (res = FALSE);
}


@view
func get_pool_volatility_adjustment_speed{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address
) -> (res: Math64x61_) {
    let (res) = pool_volatility_adjustment_speed.read(lptoken_address);
    with_attr error_message("pool volatility adjustment speed 0, liquidity pool not configured"){
        assert_not_zero(res);
    }
    return (res,);
}


func set_pool_volatility_adjustment_speed{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address, new_speed: Math64x61_
) -> () {
    assert_nn(new_speed);
    assert_not_zero(lptoken_address);
    pool_volatility_adjustment_speed.write(lptoken_address, new_speed);
    return ();
}


// @dev Here just to make sure testnet's migration can go through correctly. Will be DEPRECATED later
@external
func set_pool_volatility_adjustment_speed_external{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address, new_speed: Math64x61_
) -> () {
    Proxy.assert_only_admin();
    assert_nn(new_speed);
    assert_not_zero(lptoken_address);
    pool_volatility_adjustment_speed.write(lptoken_address, new_speed);
    return ();
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


// inefficiency and wastefulness of the functions below doesn't matter, since it will be axed before going to mainnet.
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


@view
func is_option_available{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, option_side: OptionSide, strike_price: Math64x61_, maturity: Int
) -> (option_availability: Bool) {
    let (option_address) = get_option_token_address(
        lptoken_address=lptoken_address,
        option_side=option_side,
        maturity=maturity,
        strike_price=strike_price
    );
    if (option_address == 0) {
        return (FALSE,);
    }

    return (TRUE,);
}