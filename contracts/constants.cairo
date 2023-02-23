// Enums and constants for the AMM

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import abs_value, assert_not_zero

from math64x61 import Math64x61

from interface_lptoken import ILPToken
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

// const TOKEN_ETH_ADDRESS = 0x62230ea046a9a5fbc261ac77d03c8d41e5d442db2284587570ab46455fd2488;  // devnet address
// const TOKEN_USD_ADDRESS = 456;  // devnet address
const TOKEN_ETH_ADDRESS = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;  // goerli address
const TOKEN_USD_ADDRESS = 0x5a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426;  // goerli address
const TOKEN_BTC_ADDRESS = 789;


// ############################
// Params of the AMM
// ############################

const FEE_PROPORTION_PERCENT = 3;
const RISK_FREE_RATE = 0; // Same as Math64x61.fromFelt(0)
// Stops trading x amount of seconds before given option matures.
const STOP_TRADING_BEFORE_MATURITY_SECONDS = 60 * 60 * 2;
// const STOP_TRADING_BEFORE_MATURITY_SECONDS = 60 * 2; // This is used for testing.


// ############################
// Contrants for Empiric oracle
// ############################

const EMPIRIC_ORACLE_ADDRESS = 0x446812bac98c08190dee8967180f4e3cdcd1db9373ca269904acb17f67f7093;
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

// ############################
// Constants for Chainlink oracle
// ############################

const CHAINLINK_AAVE_USD_ADDRESS = 0x6c84b8c59dd8be2cfb39c9928d38564420ca0443602a4d076eed1c53b94c583;
const CHAINLINK_BTC_USD_ADDRESS = 0x2430c441b19a8ebe1df657ad9447f056e04a90e052a62c529909d94a70e65cf;
const CHAINLINK_DAI_USD_ADDRESS = 0x1bdbbf9cabb39ede5186482cb2570c6644602ebe4a995bd8bd22b97252b133c;
const CHAINLINK_ETH_USD_ADDRESS = 0x4cbab9f923b368ec7b0551c107e650ad790170851a4daa4ed780c636c6999de;
const CHAINLINK_LINK_USD_ADDRESS = 0x5de7dbb23203290e589b743ea1a301639be3fa82247ffd6adaa23777be8c01f;
const CHAINLINK_USDC_USD_ADDRESS = 0x67be59517411ac1ee3cfd5328b24a8fb8b181eedfa888a0ae91fb57d178c309;
const CHAINLINK_USDT_USD_ADDRESS = 0x3c528d298e9b386e95fcc125add5f610db7ab7d1bdceed95fddf81856378eee;

func get_chainlink_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    quote_token_addr: Address,
    base_token_addr: Address,
) -> (chainlink_address: Address) {
    // Where quote is USDC in case of ETH/USDC, base token is ETH in case of ETH/USDC
    // and option_type is either CALL or PUT (constants.OPTION_CALL or constants.OPTION_PUT).

    if (base_token_addr == TOKEN_ETH_ADDRESS) {
        if (quote_token_addr == TOKEN_USD_ADDRESS) {
            return (CHAINLINK_ETH_USD_ADDRESS,);
        }
    }
    if (base_token_addr == TOKEN_BTC_ADDRESS) {
        if (quote_token_addr == TOKEN_USD_ADDRESS) {
            return (CHAINLINK_BTC_USD_ADDRESS,);
        }
    }
    return (0,);
}


func get_decimal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_address: Address
) -> (dec: felt) {
    if (token_address == TOKEN_ETH_ADDRESS) {
        return (18,);
    }
    if (token_address == TOKEN_USD_ADDRESS) {
        return (6,);
    }
    // FIXME: needs ERC20 intergace
    let (dec) = ILPToken.decimals(token_address);

    with_attr error_message("Specified token_address possibly does not exist - decimals=0"){
        assert_not_zero(dec);
    }
    return (dec,);
}
