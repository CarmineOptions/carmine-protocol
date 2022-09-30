// Enums and constants for the AMM

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from math64x61 import Math64x61

from types import Address
// The maximum amount of token in a pool.
const POOL_BALANCE_UPPER_BOUND = 2 ** 64 * Math64x61.FRACT_PART;
// The maximum amount of token for account balance
const ACCOUNT_BALANCE_UPPER_BOUND = 2 ** 64 * Math64x61.FRACT_PART;
// The minimum and maximum volatility
const VOLATILITY_LOWER_BOUND = 1;
const VOLATILITY_UPPER_BOUND = 2 ** 64 * Math64x61.FRACT_PART;
// Maximum strike price allowed
const STRIKE_PRICE_UPPER_BOUND = 2 ** 64 * Math64x61.FRACT_PART;

// Imagine Token A being ETH and Token B being USDC. Ie underlying asset is ETH/USDC
// TOKEN_A corresponds to ETH and TOKEN_B to USDC... Ie underlying asset is TOKEN_A/TOKEN_B
// Call pool is denominated in TOKEN_A (ETH) and Put pool in TOKEN_B (USDC). Denominated
// also means, that the liquidity is in given token.
// FIXME: look into how the tokens are actually identified
// FIXME: move the token identification to separate file
const TOKEN_A = 1;
const TOKEN_B = 2;

// option_type
// TOKEN_A is used as locked capital in OPTION_CALL
const OPTION_CALL = 0;
const OPTION_PUT = 1;

// This is used from perspective of user. When user goes long, the pool underwrites.
const TRADE_SIDE_LONG = 0;
const TRADE_SIDE_SHORT = 1;


func get_opposite_side{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    side : felt
) -> (opposite_side : felt) {
    assert (side - TRADE_SIDE_LONG) * (side - TRADE_SIDE_SHORT) = 0;
    if (side == TRADE_SIDE_LONG) {
        return (TRADE_SIDE_SHORT,);
    }
    return (TRADE_SIDE_LONG,);
}

// ############################
// Token addresses
// ############################

const TOKEN_ETH_ADDRESS = 0x62230ea046a9a5fbc261ac77d03c8d41e5d442db2284587570ab46455fd2488;
const TOKEN_USD_ADDRESS = 456;
const TOKEN_BTC_ADDRESS = 789;


// ############################
// Params of the AMM
// ############################

const FEE_PROPORTION_PERCENT = 3;
const RISK_FREE_RATE = 0; // Same as Math64x61.fromFelt(0)
// Stops trading x amount of seconds before given option matures.
// const STOP_TRADING_BEFORE_MATURITY_SECONDS = 60 * 60 * 2;
const STOP_TRADING_BEFORE_MATURITY_SECONDS = 60 * 2;


// ############################
// Contrants for Empiric oracle
// ############################

const EMPIRIC_ORACLE_ADDRESS = 0x012fadd18ec1a23a160cc46981400160fbf4a7a5eed156c4669e39807265bcd4;
const EMPIRIC_AGGREGATION_MODE = 0;  // 0 is default for median

const EMPIRIC_BTC_USD_KEY = 27712517064455012;
const EMPIRIC_ETH_USD_KEY = 28556963469423460;
const EMPIRIC_SOL_USD_KEY = 32492132765102948;
const EMPIRIC_AVAX_USD_KEY = 7022907837751063396;
const EMPIRIC_DOGE_USD_KEY = 7237116810493260644;
const EMPIRIC_SHIB_USD_KEY = 8316012582363558756;
const EMPIRIC_BNB_USD_KEY = 27705915699721060;
const EMPIRIC_ADA_USD_KEY = 27413441311765348;
const EMPIRIC_XRP_USD_KEY = 33902823363408740;
const EMPIRIC_MATIC_USD_KEY = 2017717457628037477220;


func get_empiric_key{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    quote_token_addr: Address,
    base_token_addr: Address,
) -> (empiric_key: felt) {
    // Where quote is USDC in case of ETH/USDC, base token is ETH in case of ETH/USDC
    // and option_type is either CALL or PUT (constants.OPTION_CALL or constants.OPTION_PUT).

    if (base_token_addr == TOKEN_ETH_ADDRESS) {
        if (quote_token_addr == TOKEN_USD_ADDRESS) {
            return (EMPIRIC_ETH_USD_KEY,);
        }
    }
    if (base_token_addr == TOKEN_BTC_ADDRESS) {
        if (quote_token_addr == TOKEN_USD_ADDRESS) {
            return (EMPIRIC_BTC_USD_KEY,);
        }
    }
    return (0,);
}
