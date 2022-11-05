%lang starknet

// Part of the main contract to not add complexity by having to transfer tokens between our own contracts
from constants import get_decimal
from helpers import max, _get_value_of_position, min, _get_premia_with_fees
from interface_lptoken import ILPToken
from interface_option_token import IOptionToken

from lib.pow import pow10

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import abs_value, assert_not_zero, signed_div_rem
from starkware.cairo.common.math_cmp import is_nn, is_not_zero//, is_le
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_mul,
    uint256_add,
    uint256_sub,
    uint256_unsigned_div_rem,
    uint256_le,
)
from starkware.starknet.common.syscalls import get_contract_address
from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.access.ownable.library import Ownable



// Custom conversions from Math64_61 to Uint256 and back
func toUint256{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Math64x61_,
    currency_address: Address
) -> Uint256 {
    alloc_locals;

    with_attr error_message("Failed toUint256 with input {x}, {currency_address}"){
        // converts 1.2 ETH (as Math64_61 float) to int(1.2*10**18)
        let (decimal) = get_decimal(currency_address);
        let (dec_) = pow10(decimal);
        // with_attr error_message("dec to Math64x61 Failed in toUint256"){
        //     let dec = Math64x61.fromFelt(dec_);
        // }

        // let x_ = Math64x61.mul(x, dec);
        // equivalent opperation as Math64x61.mul, but avoid the scale by 2**61
        // Math64x61.mul takes two Math64x61 and multiplies them and divides them by 2**61
        // (x*2**61) * (y*2**61) / 2**61
        // Instead we skip the "*2**61" near "y" and the "/ 2**61"
        let x_ = x * dec_;

        with_attr error_message("x_ out of bounds in toUint256"){
            assert_le(x, Math64x61.BOUND);
            assert_le(-Math64x61.BOUND, x);
        }

        let amount_felt = Math64x61.toFelt(x_);
        let res = Uint256(low = amount_felt, high = 0);
    }
    return res;
}


func fromUint256{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Uint256,
    currency_address: Address
) -> Math64x61_ {
    alloc_locals;

    let x_low = x.low;
    assert x.high = 0;

    with_attr error_message("Failed fromUint256 with input {x_low}, {currency_address}"){
        // converts 1.2*10**18 WEI to 1.2 ETH (to Math64_61 float)
        let (decimal) = get_decimal(currency_address);
        let (dec_) = pow10(decimal);
        // let dec = Math64x61.fromFelt(dec_);

        let x_ = Math64x61.fromUint256(x);
        // let x__ = Math64x61.div(x_, dec);
        // Equivalent to Math64x61.div

        // let div = abs_value(dec_);
        // let div_sign = sign(dec_);
        // no need to get sign of y, sin dec_ is positiove
        // tempvar product = x * FRACT_PART;
        // no need to to do the tempvar, since only x_ is Math64x61 and dec_ is not
        let (x__, _) = signed_div_rem(x_, dec_, Math64x61.BOUND);
        Math64x61.assert64x61(x__);
    }
    return x__;
}


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Storage vars
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


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
@storage_var
func option_position(
    lptoken_address: Address, option_side: OptionSide, maturity: Int, strike_price: Math64x61_
) -> (res: Math64x61_) {
}


// total balance of underlying in the pool (owned by the pool)
// available balance for withdraw will be computed on-demand since
// compute is cheap, storage is expensive on StarkNet currently
@storage_var
func lpool_balance(lptoken_address: Address) -> (res: Math64x61_) {
}


// Locked capital owned by the pool... above is lpool_balance describing total capital owned
// by the pool. Ie lpool_balance = pool_locked_capital + pool's unlocked capital
// Note: capital locked by users is not accounted for here.
    // Simple example:
    // - start pool with no position
    // - user sells option (user locks capital), pool pays premia and does not lock capital
    // - there is more "IERC20.balanceOf" in the pool than "pool's locked capital + unlocked capital"
@storage_var
func pool_locked_capital(lptoken_address: Address) -> (res: Math64x61_) {
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


// FIXME remove the "@external" once the contract was upgraded and the Proxy.assert_only_admin
@external
func set_available_lptoken_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    order_i: Int, lptoken_address: Address
) -> () {
    Proxy.assert_only_admin();
    available_lptoken_addresses.write(order_i, lptoken_address);
    return ();
}


@view
func get_lpool_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (res: Math64x61_) {
    let (balance) = lpool_balance.read(lptoken_address);
    return (balance,);
}


@view
func get_pool_locked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (res: Math64x61_) {
    let (locked_capital) = pool_locked_capital.read(lptoken_address);
    return (locked_capital,);
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
    // Returns capital that is unlocked for immediate extraction/use.
    // This is for example ETH in case of ETH/USD CALL options.

    // Capital locked by the pool
    let (locked_capital) = pool_locked_capital.read(lptoken_address);

    // Get capital that is sum of unlocked (available) and locked capital.
    let (contract_balance) = lpool_balance.read(lptoken_address);

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


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Get options mainly used by FE
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


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
func get_option_with_position_of_user{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    array_len : felt,
    array : felt*
) {
    alloc_locals;
    let (array : OptionWithUsersPosition*) = alloc();
    let array_len = save_option_with_position_of_user_to_array(0, array, 0, 0);

    return (array_len, array);
}


func save_option_with_position_of_user_to_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    array_len_so_far : felt,
    array : OptionWithUsersPosition*,
    pool_index: felt,
    option_index: felt
) -> felt {
    alloc_locals;

    // Stop when all the liquidity pools were iterated.
    let (lptoken_address) = get_available_lptoken_addresses(option_index);
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
            option_index=0
        );
    }
    let (option_token_address) = get_option_token_address(
        lptoken_address=lptoken_address,
        option_side=option.option_side,
        maturity=option.maturity,
        strike_price=option.strike_price
    );

    // Get users position size
    let (caller_addr) = get_caller_address();
    let (position_size_uint256) = IOptionToken.balanceOf(
        contract_address=option_token_address,
        account=caller_addr
    );
    let position_size = fromUint256(position_size_uint256, option_token_address);

    if (position_size == 0) {
        return save_option_with_position_of_user_to_array(
            array_len_so_far=array_len_so_far,
            array=array,
            pool_index=pool_index,
            option_index=option_index + 1
        );
    }

    // Get value of users positio
    let one = Math64x61.fromFelt(1);
    let (current_volatility) = get_pool_volatility(lptoken_address, option.maturity);
    let (current_pool_balance) = get_unlocked_capital(lptoken_address);
    with_attr error_message(
        "Failed getting premium in save_all_non_expired_options_with_premia_to_array"
    ){
        let (premia_with_fees) = _get_premia_with_fees(
            option=option,
            position_size=one,
            option_type=option.option_type,
            current_volatility=current_volatility,
            current_pool_balance=current_pool_balance
        );
        let premia_with_fees_x_position = Math64x61.mul(premia_with_fees, position_size);
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
        array=array,
        pool_index=pool_index,
        option_index=option_index + 1
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


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Other get functions
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


// Returns a total value of pools position (sum of value of all options held by pool).
// Goes through all options in storage var "available_options"... is able to iterate by i
// (from 0 to n)
// It gets 0 from available_option(n), if the n-1 is the "last" option.
// This could possibly use map from https://github.com/onlydustxyz/cairo-streams/
// If this doesn't look "good", there is an option to have the available_options instead of having
// the argument i, it could have no argument and return array (it might be easier for the map above)
@view
func get_value_of_pool_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address
) -> (res: Math64x61_) {
    alloc_locals;

    let (res) = _get_value_of_pool_position(lptoken_address, 0);
    return (res = res);
}


@view
func get_value_of_position{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    option: Option,
    position_size: felt,
    option_type: felt,
    current_volatility: felt,
    current_pool_balance: felt
) -> (position_value: felt){
    let (res) = _get_value_of_position(
        option,
        position_size,
        option_type,
        current_volatility,
        current_pool_balance
    );
    return (res,);
}


func _get_value_of_pool_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address, index: Int
) -> (res: Math64x61_) {
    alloc_locals;

    let (option) = available_options.read(lptoken_address, index);

    // Because of how the defined options are stored we have to verify that we have not run
    // at the end of the stored values. The end is with "empty" Option.
    let option_sum = option.maturity + option.strike_price;
    if (option_sum == 0) {
        return (res = 0);
    }

    // Get value of option at index "index"
    // In case of long position in given option, the value is equal to premia - fees.
    // In case of short position the value is equal to (locked capital - premia - fees).
    //      - the value of option is comparable to how the locked capital would be split.
    //        The option holder (long) would get equivalent to premia and the underwriter (short)
    //        would get the remaining locked capital.
    // Both scaled by the size of position.
    // option position is measured in base token (ETH in case of ETH/USD) that's why
    // the fromUint256 uses option.base_token_address
    // let (_option_position_dec) = option_position.read(
    let (_option_position) = option_position.read(
        lptoken_address,
        option.option_side,
        option.maturity,
        option.strike_price
    );
    // let _option_position_uint256 = Uint256(low=_option_position_dec, high=0);
    // let _option_position = fromUint256(_option_position_uint256, option.base_token_address);

    // If option position is 0, the value of given position is zero.
    if (_option_position == 0) {
        let (value_of_rest_of_the_pool_) = _get_value_of_pool_position(
            lptoken_address, index = index + 1
        );
        return (res = value_of_rest_of_the_pool_);
    }

    let (current_volatility) = get_pool_volatility(lptoken_address, option.maturity);
    let (current_pool_balance) = get_unlocked_capital(lptoken_address);

    with_attr error_message("Failed getting value of position in _get_value_of_pool_position"){
        let (value_of_option) = get_value_of_position(
            option,
            _option_position,
            option.option_type,
            current_volatility,
            current_pool_balance
        );
    }

    // Get value of the remaining pool
    let (value_of_rest_of_the_pool) = _get_value_of_pool_position(
        lptoken_address, index = index + 1
    );

    // Combine the two values
    let res = Math64x61.add(value_of_option, value_of_rest_of_the_pool);

    return (res = res);
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


func remove_and_shift_available_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: felt,
    index: felt

) {

    // Write zero option in provided index
    let zero_option = Option (0,0,0,0,0,0);
    available_options.write(lptoken_address, index, zero_option);
    shift_available_options(lptoken_address, index);

    return ();
}


func shift_available_options{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: felt,
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


// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
// Provide/remove liquidity
// # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


func get_lptokens_for_underlying{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    underlying_amt: Uint256
) -> (lpt_amt: Uint256) {
    // Takes in underlying_amt in quote or base tokens (based on the pool being put/call).
    // Returns how much lp tokens correspond to capital of size underlying_amt

    alloc_locals;

    with_attr error_message("Failed to get free_capital in get_lptokens_for_underlying"){
        let (free_capital_Math64) = get_unlocked_capital(lptoken_address);
        let (currency_address) = get_underlying_token_address(lptoken_address);
        let free_capital = toUint256(free_capital_Math64, currency_address);
    }

    with_attr error_message("Failed to value pools position in get_lptokens_for_underlying"){
        let (value_of_position_Math64) = get_value_of_pool_position(lptoken_address);
        let value_of_position = toUint256(value_of_position_Math64, currency_address);
    }

    with_attr error_message("Failed to get value of pool get_lptokens_for_underlying"){
        let (value_of_pool, _) = uint256_add(free_capital, value_of_position);
    }

    if (value_of_pool.low == 0) {
        return (underlying_amt,);
    }

    with_attr error_message("Failed to get to_mint get_lptokens_for_underlying"){
        let (lpt_supply) = ILPToken.totalSupply(contract_address=lptoken_address);
        let (quot, rem) = uint256_unsigned_div_rem(lpt_supply, value_of_pool);
        let (to_mint_low, to_mint_high) = uint256_mul(quot, underlying_amt);
        assert to_mint_high.low = 0;
    }

    with_attr error_message("Failed to get to_mint_additional get_lptokens_for_underlying"){
        let (to_div_low, to_div_high) = uint256_mul(rem, underlying_amt);
        assert to_div_high.low = 0;
        let (to_mint_additional_quot, to_mint_additional_rem) = uint256_unsigned_div_rem(
            to_div_low, value_of_pool
        );  // to_mint_additional_rem goes to liq pool // treasury
    }

    with_attr error_message("Failed to get mint_total get_lptokens_for_underlying"){
        let (mint_total, carry) = uint256_add(to_mint_additional_quot, to_mint_low);
        assert carry = 0;
    }
    return (mint_total,);
}

// computes what amt of underlying corresponds to a given amt of lpt.
// Doesn't take into account whether this underlying is actually free to be withdrawn.
// computes this essentially: my_underlying = (total_underlying/total_lpt)*my_lpt
// notation used: ... = (a)*my_lpt = b
@view
func get_underlying_for_lptokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    lpt_amt: Uint256
) -> (underlying_amt: Uint256) {
    // Takes in lpt_amt in terms of amount of lp tokens.
    // Returns how much underlying in quote or base tokens (based on the pool being put/call)
    // corresponds to given lp tokens.

    alloc_locals;

    let (total_lpt: Uint256) = ILPToken.totalSupply(contract_address=lptoken_address);

    with_attr error_message(
        "Failed to get free_capital_Math64 in get_underlying_for_lptokens, {lptoken_address}, {lpt_amt}"
    ){
        let (free_capital_Math64) = get_unlocked_capital(lptoken_address);
    }
    with_attr error_message(
        "Failed to get free_capital in get_underlying_for_lptokens, {lptoken_address}, {lpt_amt}, {free_capital_Math64}"
    ){
        let (currency_address) = get_underlying_token_address(lptoken_address);
        let free_capital = toUint256(free_capital_Math64, currency_address);
    }

    with_attr error_message("Failed to get value_of_position in get_underlying_for_lptokens"){
        let (value_of_position_Math64) = get_value_of_pool_position(lptoken_address);
        let value_of_position = toUint256(value_of_position_Math64, currency_address);
    }
    
    with_attr error_message("Failed to get total_underlying_amt in get_underlying_for_lptokens"){
        let (total_underlying_amt, _) = uint256_add(free_capital, value_of_position);
    }

    with_attr error_message("Failed to get to_burn_additional_quot in get_underlying_for_lptokens"){
        let (a_quot, a_rem) = uint256_unsigned_div_rem(total_underlying_amt, total_lpt);
        let (b_low, b_high) = uint256_mul(a_quot, lpt_amt);
        assert b_high.low = 0;  // bits that overflow uint256 after multiplication
        let (tmp_low, tmp_high) = uint256_mul(a_rem, lpt_amt);
        assert tmp_high.low = 0;
        let (to_burn_additional_quot, to_burn_additional_rem) = uint256_unsigned_div_rem(
            tmp_low, total_lpt
        );
    }
    with_attr error_message("Failed to get to_burn in get_underlying_for_lptokens"){
        let (to_burn, carry) = uint256_add(to_burn_additional_quot, b_low);
        assert carry = 0;
    }
    return (to_burn,);
}



// FIXME 4: add unittest that
// amount = get_underlying_for_lptokens(addr, get_lptokens_for_underlying(addr, amount))
//ie that what you get for lptoken is what you need to get same amount of lptokens


@external
func add_lptoken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    lptoken_address: Address
){
    // This function initializes the pool.

    alloc_locals;

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    // 1) Check that owner (and no other entity) is adding the lptoken
    Proxy.assert_only_admin();

    // 2) Add lptoken_address into a storage_var of lptoken_addresses
    let (lptoken_usable_index) = get_available_lptoken_addresses_usable_index(0);
    set_available_lptoken_addresses(lptoken_usable_index, lptoken_address);

    // 3) Update following
    lptoken_addr_for_given_pooled_token.write(
        quote_token_address, base_token_address, option_type, lptoken_address
    );

    let pool = Pool(
        quote_token_address=quote_token_address,
        base_token_address=base_token_address,
        option_type=option_type,
    );
    set_pool_definition_from_lptoken_address(lptoken_address, pool);

    option_type_.write(lptoken_address, option_type);
    if (option_type == OPTION_CALL) {
        // base tokens (ETH in case of ETH/USDC) for call option
        underlying_token_address.write(lptoken_address, base_token_address);
    } else {
        // quote tokens (USDC in case of ETH/USDC) for put option
        underlying_token_address.write(lptoken_address, quote_token_address);
    }

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

// FIXME: remove this external before going to mainnet
// Function for removing option 
// Currently removes only from available_options storage_var
// Beacuse it storing duplicate options would cause provide 
// wrong result when calculating value of pool's position
@external
func remove_option{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: felt,
    index: felt
) {
    alloc_locals;

    // Assert that only admin can access this function
    Proxy.assert_only_admin();

    // Remove option at given index and shift remaining options to the left
    remove_and_shift_available_options(lptoken_address, index);

    return ();
}


// Mints LPToken
// Assumes the underlying token is already approved (directly call approve() on the token being
// deposited to allow this contract to claim them)
// amt is amount of underlying token to deposit (either in base or quote based on call or put pool)
@external
func deposit_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: Address,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    amount: Uint256
) {
    alloc_locals;

    with_attr error_message("pooled_token_addr address is zero"){
        assert_not_zero(pooled_token_addr);
    }
    with_attr error_message("quote_token_address address is zero"){
        assert_not_zero(quote_token_address);
    }
    with_attr error_message("base_token_address address is zero"){
        assert_not_zero(base_token_address);
    }

    let (caller_addr) = get_caller_address();
    let (own_addr) = get_contract_address();

    with_attr error_message("Caller address is zero"){
        assert_not_zero(caller_addr);
    }
    with_attr error_message("Owner address is zero"){
        assert_not_zero(own_addr);
    }

    let (lptoken_address) = get_lptoken_address_for_given_option(
        quote_token_address, base_token_address, option_type
    );

    // Test the pooled_token_addr corresponds to the underlying token address of the pool,
    // that is defined by the quote_token_address, base_token_address and option_type
    with_attr error_message(
        "pooled_token_addr does not match the selected pool underlying token address deposit_liquidity"
    ){
        let (underlying_token_address) = get_underlying_token_address(lptoken_address);
        assert underlying_token_address = pooled_token_addr;
    }

    with_attr error_message("Failed to transfer token from account to pool"){
        // Transfer tokens to pool.
        // We can do this optimistically;
        // any later exceptions revert the transaction anyway. saves some sanity checks
        IERC20.transferFrom(
            contract_address=pooled_token_addr, sender=caller_addr, recipient=own_addr, amount=amount
        );
    }

    with_attr error_message("Failed to calculate lp tokens to be minted"){
        // Calculates how many lp tokens will be minted for given amount of provided capital.
        let (mint_amount) = get_lptokens_for_underlying(lptoken_address, amount);
    }
    with_attr error_message("Failed to mint lp tokens"){
        // Mint LP tokens
        ILPToken.mint(contract_address=lptoken_address, to=caller_addr, amount=mint_amount);
    }

    // Update the lpool_balance after the mint_amount has been computed
    // (get_lptokens_for_underlying uses lpool_balance)
    with_attr error_message("Failed to update the lpool_balance"){
        let amount_math64x61 = fromUint256(amount, underlying_token_address);
        let (current_balance) = lpool_balance.read(lptoken_address);
        let new_pb = Math64x61.add(current_balance, amount_math64x61);
        lpool_balance.write(lptoken_address, new_pb);
    }

    return ();
}


@external
func withdraw_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pooled_token_addr: Address,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
    lp_token_amount: Uint256
) {
    // lp_token_amount is in terms of lp tokens, not underlying as deposit_liquidity

    alloc_locals;

    let (caller_addr_) = get_caller_address();
    local caller_addr = caller_addr_;
    with_attr error_message("caller_addr is zero in withdraw_liquidity"){
        assert_not_zero(caller_addr);
    }
    let (own_addr) = get_contract_address();
    with_attr error_message("own_addr is zero in withdraw_liquidity"){
        assert_not_zero(own_addr);
    }

    let (lptoken_address: felt) = get_lptoken_address_for_given_option(
        quote_token_address, base_token_address, option_type
    );

    // Test the pooled_token_addr corresponds to the underlying token address of the pool,
    // that is defined by the quote_token_address, base_token_address and option_type
    with_attr error_message(
        "pooled_token_addr does not match the selected pool underlying token address withdraw_liquidity"
    ){
        let (underlying_token_address) = get_underlying_token_address(lptoken_address);
        assert underlying_token_address = pooled_token_addr;
    }

    // Get the amount of underlying that corresponds to given amount of lp tokens

    let lp_token_amount_low = lp_token_amount.low;
    with_attr error_message(
        "Failed to calculate underlying, {pooled_token_addr}, {quote_token_address}, {base_token_address}, {option_type}, {lp_token_amount_low}"
    ){
        let (underlying_amount_uint256) = get_underlying_for_lptokens(lptoken_address, lp_token_amount);
        let (currency_address) = get_underlying_token_address(lptoken_address);
        let underlying_amount_Math64 = fromUint256(underlying_amount_uint256, currency_address);
    }

    with_attr error_message(
        "Not enough 'cash' available funds in pool. Wait for it to be released from locked capital in withdraw_liquidity"
    ){
        let (free_capital) = get_unlocked_capital(lptoken_address);

        let assert_res = Math64x61.sub(free_capital, underlying_amount_Math64);

        assert_nn(assert_res);
    }

    with_attr error_message("Failed to transfer token from pool to account in withdraw_liquidity"){
        // Transfer underlying (base or quote depending on call/put)
        // We can do this transfer optimistically;
        // any later exceptions revert the transaction anyway. saves some sanity checks
        IERC20.transfer(
            contract_address=pooled_token_addr,
            recipient=caller_addr,
            amount=underlying_amount_uint256
        );
    }

    with_attr error_message("Failed to burn lp token in withdraw_liquidity"){
        // Burn LP tokens
        ILPToken.burn(contract_address=lptoken_address, account=caller_addr, amount=lp_token_amount);
    }

    with_attr error_message("Failed to write new lpool_balance in withdraw_liquidity"){
        // Update that the capital in the pool (including the locked capital).
        let (current_balance: Math64x61_) = lpool_balance.read(lptoken_address);
        let new_pb = Math64x61.sub(current_balance, underlying_amount_Math64);

        // Dont use Math.fromUint here since it would multiply the number by FRACT_PART AGAIN
        lpool_balance.write(lptoken_address, new_pb);
    }

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
            let option_size_uint256 = toUint256(option_size, base_address);
            IOptionToken.mint(option_token_address, user_address, option_size_uint256);
        }

        // Move premia and fees from user to the pool
        with_attr error_message("Failed to convert premia_including_fees to Uint256 _mint_option_token_long") {
            let premia_including_fees_uint256 = toUint256(premia_including_fees, currency_address);
        }
        with_attr error_message(
            "Failed to transfer premia and fees _mint_option_token_long {currency_address}, {user_address}, {current_contract_address}"
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
        let option_size_uint256 = toUint256(option_size, base_address);
        IOptionToken.mint(option_token_address, user_address, option_size_uint256);

        let to_be_paid_by_user = Math64x61.sub(option_size_in_pool_currency, premia_including_fees);

        // Move (option_size minus (premia minus fees)) from user to the pool
        let to_be_paid_by_user_uint256 = toUint256(to_be_paid_by_user, currency_address);
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
    let option_size_uint256 = toUint256(option_size, base_address);
    IOptionToken.burn(option_token_address, user_address, option_size_uint256);

    let premia_including_fees_uint256 = toUint256(premia_including_fees, currency_address);
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
    let option_size_uint256 = toUint256(option_size, base_address);
    IOptionToken.burn(option_token_address, user_address, option_size_uint256);

    // User receives back its locked capital, pays premia and fees
    let total_user_payment = Math64x61.sub(option_size_in_pool_currency, premia_including_fees);
    let total_user_payment_uint256 = toUint256(total_user_payment, currency_address);
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
    let long_value_uint256 = toUint256(long_value, currency_address);
    let short_value_uint256 = toUint256(short_value, currency_address);

    // Validate that the user is not burning more than he/she has.
    let (pool_definition) = get_pool_definition_from_lptoken_address(lptoken_address);
    let base_address = pool_definition.base_token_address;
    let option_size_uint256 = toUint256(option_size, base_address);
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


func adjust_lpool_balance_and_pool_locked_capital_expired_options{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    lptoken_address: Address,
    long_value: Math64x61_,
    short_value: Math64x61_,
    option_size: Math64x61_,
    option_side: OptionSide,
    maturity: Int,
    strike_price: Math64x61_
) {
    // This function is a helper function used only for expiring POOL'S options.
    // option_side is from perspektive of the pool

    alloc_locals;

    let (current_lpool_balance) = lpool_balance.read(lptoken_address);
    let (current_locked_balance) = pool_locked_capital.read(lptoken_address);
    let (current_pool_position) = option_position.read(
        lptoken_address, option_side, maturity, strike_price
    );

    let new_pool_position = Math64x61.sub(current_pool_position, option_size);
    option_position.write(lptoken_address, option_side, maturity, strike_price, new_pool_position);

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

        let new_lpool_balance = Math64x61.add(current_lpool_balance, long_value);
        lpool_balance.write(lptoken_address, new_lpool_balance);
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

        let new_lpool_balance = Math64x61.sub(current_lpool_balance, long_value);
        let new_locked_balance_1 = Math64x61.sub(current_locked_balance, short_value);
        let new_locked_balance = Math64x61.sub(new_locked_balance_1, long_value);

        with_attr error_message("Not enough capital in the pool") {
            // This will never happen since the capital to pay the users is always locked.
            assert_nn(new_lpool_balance);
            assert_nn(new_locked_balance);
        }

        lpool_balance.write(lptoken_address, new_lpool_balance);
        pool_locked_capital.write(lptoken_address, new_locked_balance);
    }
    return ();
}


func split_option_locked_capital{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: OptionType,
    option_side: OptionSide,
    option_size: Math64x61_,
    strike_price: Math64x61_,
    terminal_price: Math64x61_, // terminal price is price at which option is being settled
) -> (long_value: Math64x61_, short_value: Math64x61_) {
    alloc_locals;

    assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;

    if (option_type == OPTION_CALL) {
        // User receives max(0, option_size * (terminal_price - strike_price) / terminal_price) in base token for long
        // User receives (option_size - long_profit) for short
        let price_diff = Math64x61.sub(terminal_price, strike_price);
        let to_be_paid_quote = Math64x61.mul(option_size, price_diff);
        let to_be_paid_base = Math64x61.div(to_be_paid_quote, terminal_price);
        let (to_be_paid_buyer) = max(0, to_be_paid_base);

        let to_be_paid_seller = Math64x61.sub(option_size, to_be_paid_buyer);

        return (to_be_paid_buyer, to_be_paid_seller);
    }

    // For Put option
    // User receives  max(0, option_size * (strike_price - terminal_price)) in base token for long
    // User receives (option_size * strike_price - long_profit) for short
    let price_diff = Math64x61.sub(strike_price, terminal_price);
    let amount_x_diff_quote = Math64x61.mul(option_size, price_diff);
    let (to_be_paid_buyer) = max(0, amount_x_diff_quote);
    let to_be_paid_seller_ = Math64x61.mul(option_size, strike_price);
    let to_be_paid_seller = Math64x61.sub(to_be_paid_seller_, to_be_paid_buyer);

    return (to_be_paid_buyer, to_be_paid_seller);
}


@external
func expire_option_token_for_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lptoken_address: Address,
    option_side: OptionSide,
    strike_price: Math64x61_,
    maturity: Int,
) -> () {
    // Side is from perspective of pool!!!

    alloc_locals;

    let (option) = _get_option_info(
        lptoken_address=lptoken_address,
        option_side=option_side,
        strike_price=strike_price,
        maturity=maturity,
        starting_index=0
    );

    let quote_token_address = option.quote_token_address;
    let base_token_address = option.base_token_address;

    let option_type = option.option_type;

    // pool's position... has to be nonnegative since the position is per side (long/short)
    let (option_size) = option_position.read(lptoken_address, option_side, maturity, strike_price);

    with_attr error_message("Received negative option size"){
        assert_nn(option_size);
    }
    
    if (option_size == 0){
        // Pool's position is zero, there is nothing to expire.
        // This also checks that the option exists (if it doesn't storage_var returns 0).
        return ();
    }
    // From now on we know that pool's position is positive -> option_size > 0.

    // Make sure the contract is ready to expire
    let (current_block_time) = get_block_timestamp();
    let is_ripe = is_le(maturity, current_block_time);
    with_attr error_message("Contract isn't mature yet") {
        assert is_ripe = 1;
    }

    // Get terminal price of the option.
    let (empiric_key) = get_empiric_key(quote_token_address, base_token_address);
    let (terminal_price: Math64x61_) = get_terminal_price(empiric_key, maturity);

    let (long_value, short_value)  = split_option_locked_capital(
        option_type, option_side, option_size, strike_price, terminal_price
    );

    // Adjusts only the lpool_balance and pool_locked_capital storage_vars
    adjust_lpool_balance_and_pool_locked_capital_expired_options(
        lptoken_address=lptoken_address,
        long_value=long_value,
        short_value=short_value,
        option_size=option_size,
        option_side=option_side,
        maturity=maturity,
        strike_price=strike_price
    );

    // We have to adjust the pools option position too.
    option_position.write(lptoken_address, option_side, maturity, strike_price, 0);

    return ();
}
