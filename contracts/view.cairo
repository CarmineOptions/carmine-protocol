%lang starknet

from contracts.helpers import _get_premia_before_fees
from contracts.types import OptionWithUsersPosition

//
// @title View Functions
// @notice Collection of view functions used by the frontend and traders
//

// @notice Getter for all options
// @param lptoken_address: Address of the liquidity pool token
// @return array: Array of all options
@view
func get_all_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (
    array_len : felt,
    array : felt*
) {
    alloc_locals;
    let (array : Option*) = alloc();
    let array_len = save_option_to_array(lptoken_address, 0, array);
    return (array_len * Option.SIZE, array);
}


// @notice Adds option into the array of options
// @param lptoken_address: Address of the liquidity pool token
// @param array_len_so_far: Current length of the array
// @param array: Array containing options
// @return Array length
func save_option_to_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    array_len_so_far : felt,
    array : Option*
) -> felt {
    let (option) = get_available_options(lptoken_address, array_len_so_far);
    if (option.quote_token_address == 0 and option.base_token_address == 0) {
        return array_len_so_far;
    }

    assert [array] = option;
    return save_option_to_array(lptoken_address, array_len_so_far + 1, array + Option.SIZE);
}


// @notice Getter for all non-expired options with premia
// @param lptoken_address: Address of the liquidity pool token
// @return array: Array of non-expired options
@view
func get_all_non_expired_options_with_premia{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (
    array_len : felt,
    array : felt*
) {
    alloc_locals;
    let (array : OptionWithPremia*) = alloc();
    let array_len = save_all_non_expired_options_with_premia_to_array(lptoken_address, 0, array, 0);

    return (array_len, array);
}


// @notice Adds non-expired options with premia to the array
// @param lptoken_address: Address of the liquidity pool token
// @param array_len_so_far: Current length of the array
// @param array: Array containing options
// @param option_index: Index of the current option
// @return Array length
func save_all_non_expired_options_with_premia_to_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    array_len_so_far : felt,
    array : OptionWithPremia*,
    option_index: felt
) -> felt {
    alloc_locals;

    let (option) = get_available_options(lptoken_address, option_index);
    if (option.quote_token_address == 0 and option.base_token_address == 0) {
        return array_len_so_far;
    }

    // If option is non_expired append it, else keep going
    let (current_block_time) = get_block_timestamp();
    if (is_le(current_block_time, option.maturity) == TRUE) {
        let one = Math64x61.fromFelt(1);
        let (current_volatility) = get_pool_volatility(lptoken_address, option.maturity);

        let (current_pool_balance_uint256: Uint256) = get_unlocked_capital(lptoken_address);
        let (lpool_underlying_token: Address) = get_underlying_token_address(lptoken_address);
        let current_pool_balance: Math64x61_ = fromUint256_balance(current_pool_balance_uint256, lpool_underlying_token);

        let current_pool_balance_uint256_low = current_pool_balance_uint256.low;
        with_attr error_message(
            "Failed getting premium in save_all_non_expired_options_with_premia_to_array, cpb_uint256.low {current_pool_balance_uint256_low}"
        ){
            let (premia) = _get_premia_with_fees(
                option=option,
                position_size=one,
                option_type=option.option_type,
                current_volatility=current_volatility,
                current_pool_balance=current_pool_balance
            );
        }
        with_attr error_message(
            "Failed connecting premium and option in save_all_non_expired_options_with_premia_to_array"
        ){
            let option_with_premia = OptionWithPremia(option=option, premia=premia);
            assert [array] = option_with_premia;
        }

        return save_all_non_expired_options_with_premia_to_array(
            lptoken_address,
            array_len_so_far + OptionWithPremia.SIZE,
            array + OptionWithPremia.SIZE,
            option_index + 1
        );
    }

    return save_all_non_expired_options_with_premia_to_array(
        lptoken_address, array_len_so_far, array, option_index + 1
    );
}


// @notice Getter for all non-expired options with premia
// @param lptoken_address: Address of the liquidity pool token
// @return array: Array of non-expired options
@view
func get_option_with_position_of_user{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user_address : Address
) -> (
    array_len : felt,
    array : felt*,
) {
    alloc_locals;
    let array: OptionWithUsersPosition* = alloc();
    let array_len = save_option_with_position_of_user_to_array(0, array, 0, 0, user_address);

    return (array_len, array);
}


// @notice Calculates premia for the provided option
// @param option: Option premia will be calculated for
// @param current_volatility: Volatility of the option's pool
// @param current_pool_balance: Balance of the option's pool
// @param position_size: Size of the position
// @return res: Value for expired option and premia with fees for non-expired
func _get_premia_for_get_option_with_position_of_user{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    option: Option,
    current_volatility: Math64x61_,
    current_pool_balance: Math64x61_,
    position_size: Math64x61_
) -> (res: Math64x61_) {
    alloc_locals;

    let (current_block_time) = get_block_timestamp();
    let is_ripe = is_le(option.maturity, current_block_time);

    // If option has expired
    if (is_ripe == TRUE) {
        let quote_token_address = option.quote_token_address;
        let base_token_address = option.base_token_address;
        let (empiric_key) = get_empiric_key(quote_token_address, base_token_address);
        let (terminal_price: Math64x61_) = get_terminal_price(empiric_key, option.maturity);

        let (long_value, short_value) = split_option_locked_capital(
            option.option_type, option.option_side, position_size, option.strike_price, terminal_price
        );
        if (option.option_side == TRADE_SIDE_LONG) {
            return (long_value,);
        }
        return (short_value,);
    }

    // If option has not expired yet
    let (premia_with_fees_x_position) = _get_premia_with_fees(
        option=option,
        position_size=position_size,
        option_type=option.option_type,
        current_volatility=current_volatility,
        current_pool_balance=current_pool_balance
    );
    return (premia_with_fees_x_position, );
}


// @notice Adds option into the array of options with position of user
// @param array_len_so_far: Current length of the array
// @param array: Array containing options with user position
// @param pool_index: Index of the pool
// @param option_index: Index of the option
// @param user_address: Address of the user
// @return Array length
func save_option_with_position_of_user_to_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    array_len_so_far : felt,
    array : OptionWithUsersPosition*,
    pool_index: felt,
    option_index: felt,
    user_address: Address
) -> felt {
    alloc_locals;

    // Stop when all the liquidity pools were iterated.
    let (lptoken_address) = get_available_lptoken_addresses(pool_index);
    if (lptoken_address == 0) {
        return array_len_so_far;
    }

    // Jump to next pool when current pool's options were iterated.
    let (option) = get_available_options(lptoken_address, option_index);
    if (option.quote_token_address == 0 and option.base_token_address == 0) {
        return save_option_with_position_of_user_to_array(
            array_len_so_far=array_len_so_far,
            array=array,
            pool_index=pool_index + 1,
            option_index=0,
            user_address=user_address
        );
    }

    let (option_token_address) = get_option_token_address(
        lptoken_address=lptoken_address,
        option_side=option.option_side,
        maturity=option.maturity,
        strike_price=option.strike_price
    );

    // Get users position size
    let (position_size_uint256) = IOptionToken.balanceOf(
        contract_address=option_token_address,
        account=user_address
    );
    // Get value of users position
    let underlying_token = get_underlying_from_option_data(option.option_type, option.base_token_address, option.quote_token_address);
    let position_size = fromUint256_balance(position_size_uint256, option.base_token_address);

    if (position_size == 0) {
        return save_option_with_position_of_user_to_array(
            array_len_so_far=array_len_so_far,
            array=array,
            pool_index=pool_index,
            option_index=option_index + 1,
            user_address=user_address
        );
    }

    // Get value of users position
    let (_current_volatility) = get_pool_volatility(lptoken_address, option.maturity);
    let (current_pool_balance_uint256: Uint256) = get_unlocked_capital(lptoken_address);
    let (lpool_underlying_token: Address) = get_underlying_token_address(lptoken_address);
    let current_pool_balance: Math64x61_ = fromUint256_balance(current_pool_balance_uint256, lpool_underlying_token);

    let (_, current_volatility) = get_new_volatility(
        _current_volatility,
        position_size,
        option.option_type,
        option.option_side,
        option.strike_price,
        current_pool_balance
    );
    
    with_attr error_message(
        "Failed getting premium in save_option_with_position_of_user_to_array"
    ){
        let (premia_with_fees_x_position) = _get_premia_for_get_option_with_position_of_user(
            option, current_volatility, current_pool_balance, position_size
        );
    }

    // Create OptionWithUsersPosition and append to array
    let option_with_users_position = OptionWithUsersPosition(
        option=option,
        position_size=position_size_uint256,
        value_of_position=premia_with_fees_x_position,
    );

    assert [array] = option_with_users_position;

    return save_option_with_position_of_user_to_array(
        array_len_so_far=array_len_so_far + OptionWithUsersPosition.SIZE,
        array=array + OptionWithUsersPosition.SIZE,
        pool_index=pool_index,
        option_index=option_index + 1,
        user_address=user_address
    );
}


// @notice Getter for all liquidity pool addresses
// @return array: Array of liquidity pool addresses
@view
func get_all_lptoken_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (
    array_len : felt,
    array : Address*
) {
    alloc_locals;
    let (array : Address*) = alloc();
    let array_len = save_lptoken_addresses_to_array(0, array);
    return (array_len, array);
}


// @notice Adds addresses into the array
// @param array_len_so_far: Current length of the array
// @param array: Array containing options with user position
// @param pool_index: Index of the pool
// @param option_index: Index of the option
// @param user_address: Address of the user
// @return Array length
func save_lptoken_addresses_to_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    array_len_so_far : felt,
    array : Address*
) -> felt {
    let (lptoken_address) = get_available_lptoken_addresses(array_len_so_far);
    if (lptoken_address == 0) {
        return array_len_so_far;
    }

    assert [array] = lptoken_address;
    return save_lptoken_addresses_to_array(array_len_so_far + 1, array + 1);
}


// @notice Retrieve pool information for the given user
// @param user: User's wallet address
// @return user_pool_infos: Information about user's stake in the liquidity pools
@view
func get_user_pool_infos{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
} (user: Address) -> (
    user_pool_infos_len: felt,
    user_pool_infos: UserPoolInfo*
) {
    alloc_locals;
    let (lptoken_addrs_len: felt, lptoken_addrs: Address*) = get_all_lptoken_addresses();
    let (user_pool_infos: UserPoolInfo*) = alloc();

    let (user_pool_infos_len: felt) = map_and_filter_address_to_userpoolinfo(
        user, lptoken_addrs, lptoken_addrs_len, user_pool_infos
    );

    return (user_pool_infos_len, user_pool_infos);
}


// @notice Filter out pools with no user stake
// @param user_addr: Address of the user's wallet
// @param lptoken_addrs: Array of the liquidity pool token addresses
// @param lptoken_addrs_len: Length of the liquidity pool token addresses array
// @param user_pool_infos: Array of the UserPoolInfos
// @return user_pool_info_len: Length of the UserPoolInfos array
func map_and_filter_address_to_userpoolinfo{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
} (
    user_addr: Address,
    lptoken_addrs: Address*,
    lptoken_addrs_len: felt,
    user_pool_infos: UserPoolInfo*
)-> (user_pool_info_len: felt){

    if (lptoken_addrs_len == 0){
        return (0,);
    }

    with_attr error_message(
        "Failed getting user_pool_info in map_and_filter_address_to_userpoolinfo"
    ){
        let user_pool_info = get_one_user_pool_info(user_addr, lptoken_addrs[0]);
    }

    if (user_pool_info.value_of_user_stake.low == 0 and user_pool_info.value_of_user_stake.high == 0){
        return map_and_filter_address_to_userpoolinfo(
            user_addr, lptoken_addrs + 1, lptoken_addrs_len - 1, user_pool_infos
        );
    }

    assert [user_pool_infos] = user_pool_info;

    let (user_pool_infos_len: felt) = map_and_filter_address_to_userpoolinfo(
        user_addr, lptoken_addrs + 1, lptoken_addrs_len - 1, user_pool_infos + UserPoolInfo.SIZE
    );

    return (user_pool_infos_len + 1,);
}


// @notice Retrieves user's capital in the pool and PoolInfo
// @param user_addr: Address of the user's wallet
// @param lptoken_addrs: Address of the liquidity pool token
// @return UserPoolInfo: User's capital in the pool and PoolInfo
func get_one_user_pool_info{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_address: Address,
    lptoken_address: Address
) -> UserPoolInfo {
    alloc_locals;

    let pool_info = get_poolinfo(lptoken_address);
    let (lptoken_balance: Uint256) = ILPToken.balanceOf(
        contract_address=lptoken_address,
        account=user_address
    );
    if (lptoken_balance.low == 0 and lptoken_balance.high == 0){
        let zero_val = Uint256(0, 0);
        let res = UserPoolInfo(
            value_of_user_stake=zero_val,
            size_of_users_tokens=Uint256(0, 0),
            pool_info=pool_info
        );
        return res;
    }

    let (value_of_user_stake: Uint256) = get_underlying_for_lptokens(
        lptoken_address, lptoken_balance
    );

    let user_pool_info = UserPoolInfo(
        value_of_user_stake=value_of_user_stake,
        size_of_users_tokens=lptoken_balance,
        pool_info=pool_info
    );

    return user_pool_info;
}


// @notice Retrieves PoolInfo for all liquidity pools
// @return pool_info: Array of PoolInfo
@view
func get_all_poolinfo{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
) -> (
    pool_info_len: felt,
    pool_info: PoolInfo*
) {
    alloc_locals;
    let (lptoken_addrs_len: felt, lptoken_addrs: Address*) = get_all_lptoken_addresses();
    let (res: PoolInfo*) = alloc();
    map_address_to_poolinfo(lptoken_addrs, res, lptoken_addrs_len, 0);

    // return (lptoken_addrs_len * PoolInfo.SIZE, res);
    return (lptoken_addrs_len, res);
}


// @notice Map address to PoolInfo struct
// @param lpt_addrs: Array of liquidity pool tokens addresses 
// @param poolinfo: Array of PoolInfo structs
// @param lpt_addrs_len: Length of liquidity pool tokens addresses array
// @param curr_index: Current index
func map_address_to_poolinfo{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    lpt_addrs: Address*,
    poolinfo: PoolInfo*,
    lpt_addrs_len: felt,
    curr_index: felt
) -> () {
    let val = get_poolinfo(lpt_addrs[curr_index]);
    assert poolinfo[curr_index] = val;
    if(lpt_addrs_len == curr_index + 1){
        return ();
    }
    return map_address_to_poolinfo(lpt_addrs, poolinfo, lpt_addrs_len, curr_index + 1);
}


// @notice Retrieves PoolInfo for the provided pool
// @param lptoken_address: Address of the liquidity pool token
// @return pool_info: Information about the pool
func get_poolinfo{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address
) -> PoolInfo {
    alloc_locals;
    with_attr error_message("unable to get prerequisites for poolinfo"){
        let (pool: Pool) = pool_definition_from_lptoken_address.read(lptoken_address);
        let (current_balance) = get_lpool_balance(lptoken_address);
        let (free_capital) = get_unlocked_capital(lptoken_address);
        let (value_of_position) = get_value_of_pool_position(lptoken_address);
    }
    let res = PoolInfo(pool, lptoken_address, current_balance, free_capital, value_of_position);
    return res;
}


// @notice Retrieves option struct
// @param lptoken_address: Address of the liquidity pool token
// @param option_token_address: Address of the option token
// @return option: Option struct
@view
func get_option_info_from_addresses{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address,
    option_token_address: Address
) -> (option: Option) {
    // Returns Option (struct) information.

    alloc_locals;

    let (option) = _get_option_info_from_addresses(
        lptoken_address=lptoken_address,
        option_token_address=option_token_address,
        starting_index=1
    );

    return (option = option);
}


// @notice Helper function for retrieving option struct
// @param lptoken_address: Address of the liquidity pool token
// @param option_token_address: Address of the option token
// @param starting_index: Current index
// @return option: Option struct
func _get_option_info_from_addresses{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address,
    option_token_address: Address,
    starting_index: felt
) -> (option: Option) {
    alloc_locals;

    let (option_) = available_options.read(lptoken_address, starting_index);

    // Verify that we have not run at the end of the stored values. The end is with "empty" Option.
    with_attr error_message("Specified option is not available"){
        let option_sum = option_.maturity + option_.strike_price;
        assert_not_zero(option_sum);
    }

    let (tested_option_token_address) = get_option_token_address(
        lptoken_address, option_.option_side, option_.maturity, option_.strike_price
    );

    if (tested_option_token_address == option_token_address) {
        return (option=option_);
    }

    let (option) = _get_option_info_from_addresses(
        lptoken_address=lptoken_address,
        option_token_address=option_token_address,
        starting_index=starting_index+1
    );

    return (option = option);
}


// @notice Helper function for retrieving option with the correct side
// @param _option: Option with potentially incorrect side
// @param is_closing: Is the position being closed or opened
// @return option: Option struct
func _get_option_with_correct_side{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
} (
    _option: Option,
    is_closing: Bool,
) -> (option: Option) {

    if (is_closing == 1) {
        let (opposite_side) = get_opposite_side(_option.option_side);
        let option = Option (
            option_side = opposite_side,
            maturity = _option.maturity,
            strike_price = _option.strike_price,
            quote_token_address = _option.quote_token_address,
            base_token_address = _option.base_token_address,
            option_type = _option.option_type
        );
        return (option,);

    } else {

        return (_option,);
    }
}


// @notice Calculates premia for the provided option
// @param _option: Option for which premia is being calculated
// @param lptoken_address: Address of the liquidity pool token
// @param position_size: Size of the position
// @param is_closing: Is the position being closed or opened
// @return total_premia_before_fees: Premia
// @return total_premia_including_fees: Premia with fees
@view
func get_total_premia{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    _option: Option,
    lptoken_address: Address,
    position_size: Uint256,
    is_closing: Bool,
) -> (
    total_premia_before_fees: Math64x61_,
    total_premia_including_fees: Math64x61_
) {
    alloc_locals;
    with_attr error_message("Error in prep"){
        let (option) = _get_option_with_correct_side(_option, is_closing);

        let (current_volatility) = get_pool_volatility(lptoken_address, option.maturity);
        let (current_pool_balance) = get_unlocked_capital(lptoken_address);
        let underlying = get_underlying_from_option_data(option.option_type, option.base_token_address, option.quote_token_address);
    }
    with_attr error_message(
        "Failed while converting pool balance and position size"
    ){
        let current_pool_balance_m64x61 = fromUint256_balance(current_pool_balance, underlying);
        let position_size_m64x61 = fromUint256_balance(position_size, option.base_token_address);
    }
    with_attr error_message(
        "Failed when getting premia before fees in view.get_total_premia_including_fees"
    ){
        let (total_premia_before_fees) = _get_premia_before_fees(
            option=option,
            position_size=position_size_m64x61,
            option_type=option.option_type,
            current_volatility=current_volatility,
            current_pool_balance=current_pool_balance_m64x61
        );
    }
    
    with_attr error_message("Failed when calculating fees in view.get_total_premia_before_fees") {

        with_attr error_message("Received negative fees in view.get_total_premia") {
            let (total_fees) = get_fees(total_premia_before_fees);
            assert_nn(total_fees);
        }

        with_attr error_message("Received negative premia with fees in view.get_total_premia"){
            let (total_premia_including_fees) = add_premia_fees(option.option_side, total_premia_before_fees, total_fees);
            assert_nn(total_premia_including_fees);
        }

    }

    return (
        total_premia_before_fees = total_premia_before_fees,
        total_premia_including_fees = total_premia_including_fees,
    );
}
