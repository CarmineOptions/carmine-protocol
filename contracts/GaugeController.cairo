
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp, get_contract_address
from starkware.cairo.common.math import assert_le, assert_not_zero, assert_not_equal
from starkware.cairo.common.math_cmp import is_le, is_le_felt
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (Uint256, uint256_le, uint256_lt, uint256_check, uint256_eq, uint256_sqrt, uint256_unsigned_div_rem)
from contracts.utils.math import uint256_checked_add, uint256_checked_sub_lt, uint256_checked_mul, uint256_felt_checked_mul,uint256_checked_sub_le
from starkware.starknet.common.messages import send_message_to_l1


# 7 * 86400 seconds - all future times are rounded by week
const WEEK = 995000

# Cannot change weight votes more often than once in 10 days
const WEIGHT_VOTE_DELAY = 10 * 86400

struct Point:
    member bias : felt
    member slope : felt
end

struct VotedSlope:
    member slope : felt
    member power : felt
    member end : felt
end

@contract_interface
namespace VotingEscrow:
    func get_last_user_slope(addr:felt) -> (last_user_slope: felt):
    end

    func locked_end(addr:felt) -> (locked: felt):
    end

end

@event
func owner_change_initiated(current_owner: felt, future_owner: felt):
end
