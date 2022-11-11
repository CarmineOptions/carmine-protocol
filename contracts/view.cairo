%lang starknet

// This file contains view functions that are to be called only from the frontend (and by traders).
// In no case should code in any other file call any function here. (Except for tests of course.)

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
        let (current_pool_balance) = get_unlocked_capital(lptoken_address);

        with_attr error_message(
            "Failed getting premium in save_all_non_expired_options_with_premia_to_array"
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
    let position_size = fromUint256_balance(position_size_uint256, option_token_address);

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
    let one = Math64x61.fromFelt(1);
    let (current_volatility) = get_pool_volatility(lptoken_address, option.maturity);
    let (current_pool_balance) = get_unlocked_capital(lptoken_address);
    with_attr error_message(
        "Failed getting premium in save_all_non_expired_options_with_premia_to_array"
    ){
        let (premia_with_fees_x_position) = _get_premia_for_get_option_with_position_of_user(
            option, current_volatility, current_pool_balance, position_size
        );
    }

    // Create OptionWithUsersPosition and append to array
    let option_with_users_position = OptionWithUsersPosition(
        option=option,
        position_size=position_size,
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

// Returns UserPoolInfo, which is the value of user's capital in pool and PoolInfo.
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
        let res = UserPoolInfo(value_of_user_stake=zero_val, pool_info=pool_info);
        return res;
    }

    let (value_of_user_stake: Uint256) = get_underlying_for_lptokens(
        lptoken_address, lptoken_balance
    );

    let user_pool_info = UserPoolInfo(
        value_of_user_stake=value_of_user_stake,
        pool_info=pool_info
    );

    return user_pool_info;
}


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


func get_poolinfo{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address
) -> PoolInfo {
    alloc_locals;
    with_attr error_message("unable to get prerequisites for poolinfo"){
        let (pool: Pool) = pool_definition_from_lptoken_address.read(lptoken_address);
        let (current_balance) = lpool_balance.read(lptoken_address);
        let (free_capital) = get_unlocked_capital(lptoken_address);
        let (value_of_position) = get_value_of_pool_position(lptoken_address);
    }
    let res = PoolInfo(pool, lptoken_address, current_balance, free_capital, value_of_position);
    return res;
}


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


func _get_option_info_from_addresses{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address,
    option_token_address: Address,
    starting_index: felt
) -> (option: Option) {
    // Returns Option (struct) information.

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
