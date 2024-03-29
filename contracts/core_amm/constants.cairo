%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import abs_value, assert_not_zero

from math64x61 import Math64x61

from interfaces.interface_lptoken import ILPToken
from types import Address

const SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES = 1;

//
// @title Constants Contract
//


// The maximum amount of token in a pool.
const POOL_BALANCE_UPPER_BOUND = 2 ** 64 * Math64x61.FRACT_PART;
// The maximum amount of token for account balance
const ACCOUNT_BALANCE_UPPER_BOUND = 2 ** 64 * Math64x61.FRACT_PART;
// The minimum and maximum volatility
const VOLATILITY_LOWER_BOUND = 1;
const VOLATILITY_UPPER_BOUND = 2 ** 64 * Math64x61.FRACT_PART;
// option_type
const OPTION_CALL = 0;
const OPTION_PUT = 1;

// Long/short is used from perspective of user. When user goes long, the pool underwrites.
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

//const TOKEN_ETH_ADDRESS = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;  // goerli address
//const TOKEN_USD_ADDRESS = 0x5a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426;  // goerli address

const TOKEN_ETH_ADDRESS = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7; // mainnet, really the same
const TOKEN_USD_ADDRESS = 0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8; // mainnet


// ############################
// Params of the AMM
// ############################

const FEE_PROPORTION_PERCENT = 3;
const RISK_FREE_RATE = 0; // Same as Math64x61.fromFelt(0)
// Stops trading x amount of seconds before given option matures.
// ie stops buy/sell and close of given options (only those that are close to expiry)
// as a consequence the pricing of a position of liquidity pool is not working so the deposit/withraw is not working
const STOP_TRADING_BEFORE_MATURITY_SECONDS = 60 * 60 * 2;


// ############################
// Constants for Empiric oracle
// ############################

// TESTNET
// const EMPIRIC_ORACLE_ADDRESS = 0x446812bac98c08190dee8967180f4e3cdcd1db9373ca269904acb17f67f7093;
// MAINNET
const EMPIRIC_ORACLE_ADDRESS = 0x0346c57f094d641ad94e43468628d8e9c574dcb2803ec372576ccc60a40be2c4;
const EMPIRIC_AGGREGATION_MODE = 0;  // 0 is default for median

const EMPIRIC_BTC_USD_KEY = 18669995996566340;
const EMPIRIC_ETH_USD_KEY = 19514442401534788;
const EMPIRIC_SOL_USD_KEY = 23449611697214276;
const EMPIRIC_AVAX_USD_KEY = 4708022307469480772;
const EMPIRIC_DOGE_USD_KEY = 4922231280211678020;
const EMPIRIC_SHIB_USD_KEY = 6001127052081976132;
const EMPIRIC_BNB_USD_KEY = 18663394631832388;
const EMPIRIC_ADA_USD_KEY = 18370920243876676;
const EMPIRIC_XRP_USD_KEY = 24860302295520068;
const EMPIRIC_MATIC_USD_KEY = 1425106761739050242884;

const EMPIRIC_USDT_USD_KEY = 6148333044652921668;
const EMPIRIC_DAI_USD_KEY = 19212080998863684;
const EMPIRIC_USDC_USD_KEY = 6148332971638477636;

// @notice Get Empiric stablecoin key based on used quote tokend
// @param quote_token_addr: Address of the quote token, USDC for ETH/USDC
// @return empiric_key: Key for the Empiric oracle if quote_token is stablecoin, else zero 
func get_empiric_stablecoin_key{syscall_ptr: felt*, range_check_ptr}(
    quote_token_addr: Address
) -> (empiric_key: felt) {
    if (quote_token_addr == TOKEN_USD_ADDRESS) {
        return (EMPIRIC_USDC_USD_KEY,);
    }
    // if (quote_token_addr == TOKEN_USDT_ADDRESS) {
    //     return (EMPIRIC_USDT_USD_KEY,);
    // }
    // if (quote_token_addr == TOKEN_DAI_ADDRESS) {
    //     return (EMPIRIC_DAI_USD_KEY,);
    // }
    return (0, );
}

// @notice Get Empiric key based on used tokens
// @param quote_token_addr: Address of the quote token, USDC for ETH/USDC
// @param base_token_addr: Address of the base token, ETH for ETH/USDC
// @return empiric_key: Key for the Empiric oracle
func get_empiric_key{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    quote_token_addr: Address,
    base_token_addr: Address,
) -> (empiric_key: felt) {
    // Where quote is USDC in case of ETH/USDC, base token is ETH in case of ETH/USDC

    if (base_token_addr == TOKEN_ETH_ADDRESS) {
        if (quote_token_addr == TOKEN_USD_ADDRESS) {
            return (EMPIRIC_ETH_USD_KEY,);
        }
    }
    // if (base_token_addr == TOKEN_BTC_ADDRESS) {
    //     if (quote_token_addr == TOKEN_USD_ADDRESS) {
    //         return (EMPIRIC_BTC_USD_KEY,);
    //     }
    // }
    return (0,);
}


// @notice Get decimal count for the given token
// @dev 18 for ETH, 6 for USDC
// @param token_address: Address of the token for which decimals are being retrieved
// @return dec: Decimal count
func get_decimal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_address: Address
) -> (dec: felt) {
    // To limit the calls outside some of the values are fixed.
    if (token_address == TOKEN_ETH_ADDRESS) {
        return (18,);
    }
    if (token_address == TOKEN_USD_ADDRESS) {
        return (6,);
    }

    with_attr error_message("Specified token_address is 0"){
        assert_not_zero(token_address);
    }

    // ILPToken is basically the same as IERC20
    let (dec) = ILPToken.decimals(token_address);

    with_attr error_message("Specified token_address possibly does not exist - decimals=0"){
        assert_not_zero(dec);
    }
    return (dec,);
}