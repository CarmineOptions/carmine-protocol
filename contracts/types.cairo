// Types used in the project

%lang starknet

using Bool = felt; // boolean
using Wad = felt; // 18 decimal floating point
using Math64x61_ = felt; // 64x61 floating point based on Math64x61 library
using OptionType = felt; // Is enum, has 0 and 1 values as boolean at the moment,
    // but the meaning is different.
    // Down the line the OptionType might get other values for for example
    // Put/Call american options.
using OptionSide = felt; // Is enum, has 0 and 1 values.
using Int = felt; // Is integer, ie "felt(1) = int(1)... felt(100) = int(100)"... for example maturity
using Address = felt;


// List of available options (mapping from 1 to n to available strike x maturity,
// for n+1 returns zeros). STARTS INDEXING AT 0.
// FIXME: add address of the option here and possibly id of liquidity pool (address of liquidity pool token)
struct Option {
    option_side: OptionSide,
    maturity: Int,
    strike_price: Math64x61_,
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
}

struct Pool {
    quote_token_address: Address,
    base_token_address: Address,
    option_type: OptionType,
}
