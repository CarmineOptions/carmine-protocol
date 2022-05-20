
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp, get_contract_address
from starkware.cairo.common.math import assert_le, assert_not_zero, assert_not_equal
from starkware.cairo.common.math_cmp import is_le, is_le_felt
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (Uint256, uint256_le, uint256_lt, uint256_check, uint256_eq, uint256_sqrt, uint256_unsigned_div_rem)
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
    member ending : felt
end

@contract_interface
namespace VotingEscrow:
    func get_last_user_slope(addr:felt) -> (last_user_slope: felt):
    end

    func locked_end(addr:felt) -> (locked: felt):
    end

end

########################################
# Events
########################################

@event
func commit_ownership(admin: felt):
end

@event
func apply_ownership(admin: felt):
end

@event
func add_type(admin: felt):
end

@event
func new_type_weight(admin: felt):
end

@event
func new_gauge_weight(admin: felt):
end

@event
func vote_for_gauege(admin: felt):
end

@event
func new_gauge(admin: felt):
end

const MULTIPLIER =10**18


########################################
# Storage variables
########################################

# Can and will be a smart contract
@storage_var
func admin_address()->(address:felt):
end

# Can and will be a smart contract
@storage_var
func future_admin()->(address:felt):
end


@storage_var
func token_address()->(address:felt):
end

# Voting escrow
@storage_var
func voting_escrow()->(address:felt):
end

@storage_var
func n_gauge_types()->(address:felt):
end

@storage_var
func n_gauges()->(address:felt):
end

@storage_var
func gauge_type_names(gauge_type:felt)->(name:felt):
end

# Needed for enumeration
@storage_var
func gauges()->(address:felt):
end

@storage_var
func gauge_types_(address:felt)->(type:felt):
end

# user -> gauge_addr -> VotedSlope
@storage_var
func vote_user_slopes(address:felt, gauge_address:felt)->(type:felt):
end

# Total vote power used by user
@storage_var
func vote_user_power(address:felt)->(vote_power:felt):
end

 # Last user vote's timestamp for each gauge address
@storage_var
func last_user_vote(address:felt,gauge_address:felt )->(timestamp:felt):
end

# gauge_addr -> time -> Point
@storage_var
func points_weight(address:felt,timestamp:felt )->(weight:Point):
end

# gauge_addr -> time -> slope
@storage_var
func changes_weight(address:felt,timestamp:felt )->(slope:felt):
end

# gauge_addr -> last scheduled time (next week)
@storage_var
func time_weight(address:felt )->(weight:felt):
end

# type_id -> time -> Point
@storage_var
func points_sum(type_id:felt, timestamp:felt )->(sum:Point):
end

# type_id -> time -> slope
@storage_var
func changes_sum(type_id:felt, timestamp:felt )->(slope:felt):
end


# type_id -> last scheduled time (next week)
@storage_var
func time_sum(type_id:felt )->(scheduled_time :felt):
end

# time -> total weight
@storage_var
func points_total(timestamp:felt )->(total_weight :felt):
end



# last scheduled time
@storage_var
func time_total( )->(time :felt):
end

# type_id -> time -> type weight
@storage_var
func points_type_weight(type_id:felt, timestamp:felt)->(type_weight :felt):
end

# type_id -> last scheduled time (next week)
@storage_var
func time_type_weight(type_id:felt)->( last_scheduled_time :felt):
end


@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
    _token:felt,
    _voting_escrow:felt,
    _admin:felt,
    ):

    with_attr error_message(""):
        assert_not_zero (_token)
        assert_not_zero(_voting_escrow)
    end
    token_address.write(_token)
    voting_escrow.write(_voting_escrow)
    admin_address.write(_admin)
    let (init_timestamp)=get_block_timestamp()
    let _time_total=unsigned_div_rem(init_timestamp,WEEK*WEEK)
    time_total.write(_time_total)
    return()
end


########################################
# View functions
########################################




########################################
# External functions
########################################

#notice Transfer ownership of GaugeController to `addr`
#param addr Address to have ownership transferred to
@external
func commit_transfer_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(future_admin: felt):
    _only_admin()
    assert_not_zero(future_admin)
    _future_admin.write(future_admin)
    return ()
end







########################################
# Internal functions
########################################
func _only_admin{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (admin) = admin_address.read()
    let (caller) = get_caller_address()
    with_attr error_message("GaugeController:: admin only")
        assert admin = caller
    end
    return ()
end
