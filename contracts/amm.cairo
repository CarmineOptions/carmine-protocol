// Internals of the AMM

%lang starknet

from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn_le, assert_nn, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import assert_uint256_le
from starkware.starknet.common.syscalls import get_block_timestamp, get_caller_address
from math64x61 import Math64x61
from lib.pow import pow10

from contracts.constants import (
    SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES,
    VOLATILITY_LOWER_BOUND,
    VOLATILITY_UPPER_BOUND,
    OPTION_CALL,
    OPTION_PUT,
    TRADE_SIDE_LONG,
    TRADE_SIDE_SHORT,
    RISK_FREE_RATE,
    STOP_TRADING_BEFORE_MATURITY_SECONDS,
    EMPIRIC_ETH_USD_KEY,
    get_empiric_key,
    get_opposite_side,
)
from contracts.events import (
    TradeOpen,
    TradeClose,
    TradeSettle,
    DepositLiquidity,
    WithdrawLiquidity,
    ExpireOptionTokenForPool
)
from contracts.fees import get_fees
from contracts.option_pricing import black_scholes
from contracts.oracles import empiric_median_price, get_terminal_price
from contracts.types import (
    Bool, Math64x61_, OptionType, OptionSide, Int, Address, Option, Pool, PoolInfo,
    OptionWithPremia, UserPoolInfo
)
from contracts.option_pricing_helpers import (
    select_and_adjust_premia,
    get_time_till_maturity,
    add_premia_fees,
    get_new_volatility,
    convert_amount_to_option_currency_from_base_uint256,
)
from helpers import intToUint256, toUint256_balance, get_underlying_from_option_data, check_deadline



// ############################
// AMM Trade, Close and Expire
// ############################


func do_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_type: OptionType,
    strike_price: Math64x61_,
    maturity: Int,
    side: OptionSide,
    option_size: Int,
    quote_token_address: Address,
    base_token_address: Address,
    lptoken_address: Address,
    limit_total_premia: Math64x61_, // Is be total premia including fees
) -> (premia: Math64x61_) {
    // options_size is always denominated in the lowest possible unit of BASE tokens (ETH in case of ETH/USDC),
    // e.g. wei in case of ETH.
    // Option size of 1 ETH would be 10**18 since 1 ETH = 10**18 wei.

    alloc_locals;

    with_attr error_message("do_trade premia calculation and updates failed") {
        // 0) Helper values
        with_attr error_message("conversions failed in do_trade"){
            let option_size_uint256 = intToUint256(option_size);
            let strike_price_uint256 = toUint256_balance(strike_price, quote_token_address);
            // option_size_in_pool_currency determines the locked capital for given option and is not used
            // in any other way
            let (option_size_in_pool_currency: Uint256) = convert_amount_to_option_currency_from_base_uint256(
                option_size_uint256,
                option_type,
                strike_price_uint256,
                base_token_address
            );
            assert option_size_in_pool_currency.high = 0;
            let option_size_m64x61 = fromInt_balance(option_size, base_token_address);
        }

        // 1) Get current volatility
        with_attr error_message("do_trade: unable to get pool vol"){
            let (current_volatility) = get_pool_volatility_auto(
                lptoken_address=lptoken_address,
                maturity=maturity,
                strike_price=strike_price
            );
        }

        // 2) Get price of underlying asset
        with_attr error_message("do_trade: error while getting current price from Empiric") {
            let (empiric_key) = get_empiric_key(quote_token_address, base_token_address);
            let (underlying_price) = empiric_median_price(empiric_key);
        }

        // 3) Calculate new volatility, calculate trade volatility
        
        with_attr error_message("do_trade: unable to calculate volatility") {
            with_attr error_message("do_trade: unable to get_pool_volatility_adjustment_speed") {
                let (pool_volatility_adjustment_speed) = get_pool_volatility_adjustment_speed(
                    lptoken_address=lptoken_address
                );
            }

            let (new_volatility, trade_volatility) = get_new_volatility(
                current_volatility, option_size_m64x61, option_type, side, strike_price, pool_volatility_adjustment_speed
            );

            local newvol = new_volatility;
            local adjspd = pool_volatility_adjustment_speed;
            local optsize = option_size_m64x61;
            // 4) Update volatility
            with_attr error_message("do_trade: unable to update volatility to {newvol}, adjusting at {adjspd}, optsize {optsize}") {
                set_pool_volatility_separate(
                    lptoken_address=lptoken_address,
                    maturity=maturity,
                    strike_price=strike_price,
                    volatility=new_volatility
                );
            }
        }

        // 5) Get time till maturity
        let (time_till_maturity) = get_time_till_maturity(maturity);

        // 6) risk free rate
        let risk_free_rate_annualized = RISK_FREE_RATE;

        // 7) Get premia
        // call_premia, put_premia in quote tokens (USDC in case of ETH/USDC)
        with_attr error_message("error while calculating premia") {
            let HUNDRED = Math64x61.fromFelt(100);
            let sigma = Math64x61.div(trade_volatility, HUNDRED);
            let (call_premia, put_premia) = black_scholes(
                sigma=sigma,
                time_till_maturity_annualized=time_till_maturity,
                strike_price=strike_price,
                underlying_price=underlying_price,
                risk_free_rate_annualized=risk_free_rate_annualized,
            );
            // AFTER THE LINE BELOW, THE PREMIA IS IN TERMS OF CURRENCY OF CORRESPONDING POOL
            // Ie in case of call option, the premia is in base (ETH in case ETH/USDC)
            // and in quote tokens (USDC in case of ETH/USDC) for put option.
            let (premia) = select_and_adjust_premia(
                call_premia, put_premia, option_type, underlying_price
            );
            // premia adjusted by size (multiplied by size)
            let total_premia_before_fees = Math64x61.mul(premia, option_size_m64x61);
        }

        // 8) Get fees
        // fees are already in the currency same as premia
        // if side == TRADE_SIDE_LONG (user pays premia) the fees are added on top of premia
        // if side == TRADE_SIDE_SHORT (user receives premia) the fees are substracted from the premia
        with_attr error_message("do_trade: error while counting fees"){
            let (total_fees) = get_fees(total_premia_before_fees);
            let (total_premia) = add_premia_fees(side, total_premia_before_fees, total_fees);
        }
    }

    assert option_size_in_pool_currency.high = 0;

    // 9) Validate slippage
    with_attr error_message("Current premia with fees is out of slippage bounds (do_trade). side: {side}, limit_total_premia: {limit_total_premia}, total_premia: {total_premia}"){
        if (side == TRADE_SIDE_LONG) {
            assert_le(total_premia, limit_total_premia);
        } else {
            assert_le(limit_total_premia, total_premia);
        }
    }

    // 10) Make the trade
    mint_option_token(
        lptoken_address=lptoken_address,
        option_size=option_size,
        option_size_in_pool_currency=option_size_in_pool_currency,
        option_side=side,
        option_type=option_type,
        maturity=maturity,
        strike_price=strike_price,
        premia_including_fees=total_premia,
        underlying_price=underlying_price,
    );

    return (premia=premia);
}


func close_position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : OptionType,
    strike_price : Math64x61_,
    maturity : Int,
    side : OptionSide,
    option_size : Int, // in base token
    quote_token_address: Address,
    base_token_address: Address,
    lptoken_address: Address,
    limit_total_premia: Math64x61_, // Should be total premia including fees - w.r.t. to opposite side
) -> (premia : Math64x61_) {
    // All of the unlocking of capital happens inside of the burn function below.e

    // When the user is closing, side is the side of the token being closed... for calculations
    // we need opposite side, since the user is doing "opposite" action
    // to acquiring the option token.

    alloc_locals;

    // 0) Helper values
    with_attr error_message("conversions failed in close_position"){
        let (opposite_side) = get_opposite_side(side);

        let option_size_uint256 = intToUint256(option_size);
        let strike_price_uint256 = toUint256_balance(strike_price, quote_token_address);
    }
    let (option_size_in_pool_currency) = convert_amount_to_option_currency_from_base_uint256(
        option_size_uint256,
        option_type,
        strike_price_uint256,
        base_token_address
    );
    assert option_size_in_pool_currency.high = 0;

    let option_size_m64x61 = fromInt_balance(option_size, base_token_address);

    // 1) Get current volatility
    let (current_volatility) = get_pool_volatility_auto(
        lptoken_address=lptoken_address,
        maturity=maturity,
        strike_price=strike_price
    );

    // 2) Get price of underlying asset
    let (empiric_key) = get_empiric_key(quote_token_address, base_token_address);
    let (underlying_price) = empiric_median_price(empiric_key);

    // 3) Calculate new volatility, calculate trade volatility
    let (pool_volatility_adjustment_speed) = get_pool_volatility_adjustment_speed(
        lptoken_address=lptoken_address
    );
    let (new_volatility, trade_volatility) = get_new_volatility(
        current_volatility, option_size_m64x61, option_type, opposite_side, strike_price, pool_volatility_adjustment_speed
    );

    // 4) Update volatility
    set_pool_volatility_separate(
        lptoken_address=lptoken_address,
        maturity=maturity,
        strike_price=strike_price,
        volatility=new_volatility
    );

    // 5) Get time till maturity
    let (time_till_maturity) = get_time_till_maturity(maturity);

    // 6) risk free rate
    let risk_free_rate_annualized = RISK_FREE_RATE;

    // 7) Get premia
    // call_premia, put_premia in quote tokens (USDC in case of ETH/USDC)
    let HUNDRED = Math64x61.fromFelt(100);
    let sigma = Math64x61.div(trade_volatility, HUNDRED);
    let (call_premia, put_premia) = black_scholes(
        sigma=sigma,
        time_till_maturity_annualized=time_till_maturity,
        strike_price=strike_price,
        underlying_price=underlying_price,
        risk_free_rate_annualized=risk_free_rate_annualized,
    );
    // AFTER THE LINE BELOW, THE PREMIA IS IN TERMS OF CORRESPONDING POOL
    // Ie in case of call option, the premia is in base (ETH in case ETH/USDC)
    // and in quote tokens (USDC in case of ETH/USDC) for put option.
    let (premia) = select_and_adjust_premia(
        call_premia, put_premia, option_type, underlying_price
    );
    // premia adjusted by size (multiplied by size)
    let total_premia_before_fees = Math64x61.mul(premia, option_size_m64x61);

    // 8) Get fees
    // fees are already in the currency same as premia
    // if opposite_side == TRADE_SIDE_LONG (user pays premia) the fees are added on top of premia
    // if opposite_side == TRADE_SIDE_SHORT (user receives premia) the fees are substracted from the premia
    let (total_fees) = get_fees(total_premia_before_fees);
    let (total_premia) = add_premia_fees(opposite_side, total_premia_before_fees, total_fees);

    // 9) Validate slippage
    with_attr error_message("Current premia with fees is out of slippage bounds (close_position). opposite_side: {opposite_side}, limit_total_premia: {limit_total_premia}, total_premia: {total_premia}"){
        if (opposite_side == TRADE_SIDE_LONG) {
            assert_le(total_premia, limit_total_premia);
        } else {
            assert_le(limit_total_premia, total_premia);
        }
    }

    // 10) Make the trade
    with_attr error_message("Unable to burn option token in close_position"){
        burn_option_token(
            lptoken_address=lptoken_address,
            option_size=option_size,
            option_size_in_pool_currency=option_size_in_pool_currency,
            option_side=side,
            option_type=option_type,
            maturity=maturity,
            strike_price=strike_price,
            premia_including_fees=total_premia,
            underlying_price=underlying_price
        );
    }
    
    return (premia=premia);
}

func validate_trade_input{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : OptionType,
    strike_price : Math64x61_,
    maturity : Int,
    option_side : OptionSide,
    option_size : Int,
    quote_token_address: Address,
    base_token_address: Address,
    lptoken_address: Address,
    open_position: Bool,
    limit_total_premia: Math64x61_,
    tx_deadline: Int,
) {
    alloc_locals;

    with_attr error_message("Trading is currently halted."){
        let (halt_status) = get_trading_halt();
        assert halt_status = 0;
    }

    with_attr error_message("Given option_type is not available") {
        assert (option_type - OPTION_CALL) * (option_type - OPTION_PUT) = 0;
    }

    with_attr error_message("Given option_side is not available") {
        assert (option_side - TRADE_SIDE_LONG) * (option_side - TRADE_SIDE_SHORT) = 0;
    }

    with_attr error_message("open_position is not bool") {
        assert (open_position - TRUE) * (open_position - FALSE) = 0;
    }

    // Check that option_size>0 (same as size>=1... because 1 is a smallest unit)
    with_attr error_message("Option size is not positive") {
        assert_le(1, option_size);
    }

    // lptoken_address serves as an identifier of selected liquidity pool
    let (option_is_available) = is_option_available(
        lptoken_address,
        option_side,
        strike_price,
        maturity
    );
    with_attr error_message("Option is not available") {
        assert option_is_available = TRUE;
    }

    // Check that maturity hasn't matured in case of open_position=TRUE
    // If open_position=FALSE it means the user wants to close or settle the option
    let (current_block_time) = get_block_timestamp();
    if (open_position == TRUE) {
        with_attr error_message("Given maturity has already expired") {
            assert_le(current_block_time, maturity);
        }
        with_attr error_message("Trading of given maturity has been stopped before expiration") {
            assert_le(current_block_time, maturity - STOP_TRADING_BEFORE_MATURITY_SECONDS);
        }
        tempvar range_check_ptr = range_check_ptr;
    } else {
        let is_not_ripe = is_le(current_block_time, maturity);
        let cannot_be_closed = is_le(maturity - STOP_TRADING_BEFORE_MATURITY_SECONDS, current_block_time);
        let cannot_be_closed_or_settled = is_not_ripe * cannot_be_closed;
        with_attr error_message(
            "Closing positions or settling option of given maturity is not possible just before expiration"
        ) {
            assert cannot_be_closed_or_settled = 0;
        }
        tempvar range_check_ptr = range_check_ptr;
    }

    // Check that limit_total_premia>0
    with_attr error_message("Total limit for premia is not positive") {
        assert_le(1, limit_total_premia);
    }

    // Check that tx_deadline>0
    with_attr error_message("Deadline for transaction is not positive") {
        assert_le(1, tx_deadline);
    }

    return ();
}


@external
func trade_open{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : OptionType,
    strike_price : Math64x61_,
    maturity : Int,
    option_side : OptionSide,
    option_size : Int,  // in base token currency
    quote_token_address: Address,  // part of underlying_asset definition
    base_token_address: Address,  // part of underlying_asset definition
    limit_total_premia: Math64x61_,  // The limit price that user wants
    tx_deadline: Int,  // Timestamp deadline for the transaction to happen
) -> (premia : Math64x61_) {
    // User wants to open a position

    alloc_locals;

    // lptoken_address serves as an identifier of selected liquidity pool
    let (lptoken_address) = get_lptoken_address_for_given_option(
        quote_token_address,
        base_token_address,
        option_type
    );

    // Validate the validity of the input.
    validate_trade_input(
        option_type=option_type,
        strike_price=strike_price,
        maturity=maturity,
        option_side=option_side,
        option_size=option_size,
        quote_token_address=quote_token_address,
        base_token_address=base_token_address,
        lptoken_address=lptoken_address,
        open_position=TRUE,
        limit_total_premia=limit_total_premia,
        tx_deadline=tx_deadline,
    );

    with_attr error_message("do_trade failed") {
        // Returns premium for option of size 1
        let (premia) = do_trade(
            option_type,
            strike_price,
            maturity,
            option_side,
            option_size,
            quote_token_address,
            base_token_address,
            lptoken_address,
            limit_total_premia,
        );
    }

    // Validate deadline
    check_deadline(tx_deadline);

    return (premia=premia);
}


@external
func trade_close{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : OptionType,
    strike_price : Math64x61_,
    maturity : Int,
    option_side : OptionSide,
    option_size : Int,
    quote_token_address: Address,  // Identifies underlying_asset
    base_token_address: Address,  // Identifies underlying_asset
    limit_total_premia: Math64x61_, // The limit price that user wants
    tx_deadline: Int,
) -> (premia : Math64x61_) {
    // User is closing a position before the option has expired
    //  -> side is what the user wants to close
    //      - (side of the token that user holds)
    //      - This is very important in close_position where an opposite side is used

    alloc_locals;

    // lptoken_address serves as an identifier of selected liquidity pool
    let (lptoken_address) = get_lptoken_address_for_given_option(
        quote_token_address,
        base_token_address,
        option_type
    );

    // Validate the validity of the input.
    validate_trade_input(
        option_type=option_type,
        strike_price=strike_price,
        maturity=maturity,
        option_side=option_side,
        option_size=option_size,
        quote_token_address=quote_token_address,
        base_token_address=base_token_address,
        lptoken_address=lptoken_address,
        open_position=FALSE,
        limit_total_premia=limit_total_premia,
        tx_deadline=tx_deadline,
    );

    with_attr error_message("unable to close_position in trade_close"){
        let (premia) = close_position(
            option_type,
            strike_price,
            maturity,
            option_side,
            option_size,
            quote_token_address,
            base_token_address,
            lptoken_address,
            limit_total_premia,
        );
    }

    // Validate deadline
    check_deadline(tx_deadline);
    
    return (premia=premia);

}


@external
func trade_settle{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    option_type : OptionType,
    strike_price : Math64x61_,
    maturity : Int,
    option_side : OptionSide,
    option_size : Int,
    quote_token_address: Address,  // Identifies underlying_asset
    base_token_address: Address,  // Identifies underlying_asset
) {
    // User is expiring/settling a position AFTER the option has expired
    //  -> side is what the user want's to close
    //      - (side of the token that user holds)
    //      - This is very important is in close_position an opposite side is used

    alloc_locals;

    with_attr error_message("trade_settle failed when calling get_lptoken_address_for_given_option") {
        // lptoken_address serves as an identifier of selected liquidity pool
        let (lptoken_address) = get_lptoken_address_for_given_option(
            quote_token_address,
            base_token_address,
            option_type
        );
    }

    with_attr error_message("trade_settle failed when validating trade input") {
        // Validate the validity of the input.
        validate_trade_input(
            option_type=option_type,
            strike_price=strike_price,
            maturity=maturity,
            option_side=option_side,
            option_size=option_size,
            quote_token_address=quote_token_address,
            base_token_address=base_token_address,
            lptoken_address=lptoken_address,
            open_position=FALSE,
            limit_total_premia=1, // effectively switching off this check
            tx_deadline=1677588647000,  // effectively switching off this check
        );
    }

    // Position can be expired/settled only if the maturity has passed.
    let (current_block_time) = get_block_timestamp();
    with_attr error_message("Given maturity has not passed yet") {
        assert_le(maturity, current_block_time);
    }

    with_attr error_message("trade_settle failed when fetching terminal price") {
        let (empiric_key) = get_empiric_key(quote_token_address, base_token_address);
        let (terminal_price: Math64x61_) = get_terminal_price(empiric_key, maturity);
    }

    with_attr error_message("trade_settle failed when expirying option token") {
        expire_option_token(
            lptoken_address=lptoken_address,
            option_type=option_type,
            option_side=option_side,
            strike_price=strike_price,
            terminal_price=terminal_price,
            option_size=option_size,
            maturity=maturity,
        );
    }
    return ();
}
