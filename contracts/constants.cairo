# Enums and constants for the AMM

%lang starknet

from contracts.Math64x61 import Math64x61_FRACT_PART

# The maximum amount of token in a pool.
const POOL_BALANCE_UPPER_BOUND = 2 ** 64 * Math64x61_FRACT_PART
# The maximum amount of token for account balance
const ACCOUNT_BALANCE_UPPER_BOUND = 2 ** 64 * Math64x61_FRACT_PART
# The minimum and maximum volatility
const VOLATILITY_LOWER_BOUND = 0
const VOLATILITY_UPPER_BOUND = 2 ** 64 * Math64x61_FRACT_PART
# Maximum strike price allowed
const STRIKE_PRICE_UPPER_BOUND = 2 ** 64 * Math64x61_FRACT_PART

# Imagine Token A being ETH and Token B being USDC. Ie underlying asset is ETH/USDC
# TOKEN_A corresponds to ETH and TOKEN_B to USDC... Ie underlying asset is TOKEN_A/TOKEN_B
# Call pool is denominated in TOKEN_A (ETH) and Put pool in TOKEN_B (USDC). Denominated
# also means, that the liquidity is in given token.
# FIXME: look into how the tokens are actually identified
# FIXME: move the token identification to separate file
const TOKEN_A = 1
const TOKEN_B = 2

# option_type
# TOKEN_A is used as locked capital in OPTION_CALL
const OPTION_CALL = 0
const OPTION_PUT = 1

# This is used from perspective of user. When user goes long, the pool underwrites.
const TRADE_SIDE_LONG = 0
const TRADE_SIDE_SHORT = 1
