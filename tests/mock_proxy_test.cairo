%lang starknet 

from starkware.cairo.common.cairo_builtins import HashBuiltin

struct DummyStruct {
    field_one: felt,
    field_two: felt,
}

// SINGLE DUMMY
@storage_var
func dummy_storage() -> (res: DummyStruct) {
}

@external
func read_dummy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: DummyStruct) {

    let res = dummy_storage.read();

    return (res);
}

@external
func alter_dummy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(val: DummyStruct) {

    dummy_storage.write(val);

    return ();
}

//===================================================
// DUMMY INPUT

@storage_var 
func dummy_storage_input(input: felt) -> (res: DummyStruct) {
}

@external
func read_dummy_input{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(input: felt) -> (res: DummyStruct) {

    let res = dummy_storage_input.read(input);

    return (res);
}

@external
func alter_dummy_input{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(input:felt, val: DummyStruct) {

    dummy_storage_input.write(input, val);

    return ();
}

//===================================================
// DUMMY STORAGE STRUCT

@storage_var
func dummy_storage_struct(input: DummyStruct) -> (res: felt) {
}

@external
func read_dummy_struct{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(input: DummyStruct) -> (res: felt) {

    let res = dummy_storage_struct.read(input);

    return (res);
}

@external
func alter_dummy_struct{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(input: DummyStruct, val: felt) {

    dummy_storage_struct.write(input, val);

    return ();
}


//===================================================

// @storage_var 
// func dummy_storage_struct_input(input: DummyStruct) -> (res: DummyStruct) {
// }


// PROXY UTILS
from openzeppelin.upgrades.library import Proxy

// Initializer

@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    proxy_admin: felt
) {
    Proxy.initializer(proxy_admin);
    return ();
}

// Upgrades

@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_implementation: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(new_implementation);
    return ();
}

// Admin related functions

@view
func getAdmin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    let (address) = Proxy.get_admin();
    return (address,);
}

@external
func setAdmin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) {
    Proxy.assert_only_admin();
    Proxy._set_admin(address);
    return ();
}

// Other utils

@view
func getImplementationHash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    implementation_hash: felt
) {
    let (implementation_hash) = Proxy.get_implementation_hash();
    return (implementation_hash = implementation_hash);
} 