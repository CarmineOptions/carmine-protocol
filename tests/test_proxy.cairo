%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

struct DummyStruct {
    field_one: felt,
    field_two: felt,
}

@contract_interface
namespace IMockProxy {
    func read_dummy() -> (res: DummyStruct){
    }

    func alter_dummy(val: DummyStruct) {
    }

    func read_dummy_input(input: felt) -> (res: DummyStruct) {
    }

    func alter_dummy_input(input: felt, val: DummyStruct) {
    }

    func read_dummy_struct(input: DummyStruct) -> (res: felt){
    }

    func alter_dummy_struct(input: DummyStruct, val: felt) {
    }

    func initializer(proxy_admin: felt) {
    }

    func upgrade(new_implementation: felt) {
    }

    func getAdmin() -> (address: felt) {
    }

    func setAdmin(address: felt) {
    }

    func getImplementationHash() -> (implementation_hash: felt) {
    }
}

@external
func __setup__{syscall_ptr: felt*, range_check_ptr}(){

    tempvar proxy_addr;

    %{
        proxy_mock_hash = declare(
            "tests/mock_proxy_test.cairo"
        ).class_hash

        context.proxy_addr = deploy_contract(
            "proxy_contract/proxy.cairo",
            [proxy_mock_hash, 0, 0]
        ).contract_address

    %}

    return ();
}

@external
func test_proxy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){

    tempvar proxy_addr;
    %{
        ids.proxy_addr = context.proxy_addr

        # Start pranking the admin address
        stop_address_prank_old = start_prank(124, target_contract_address = ids.proxy_addr)

    %}

    IMockProxy.initializer(proxy_addr, 124);
    let (admin_addr) = IMockProxy.getAdmin(proxy_addr);
    assert admin_addr = 124;

    // Set new admin
    IMockProxy.setAdmin(proxy_addr, 125);

    %{
        # Stop pranking the old admin address and prank the new one
        stop_address_prank_old()
        stop_address_prank_new = start_prank(125, target_contract_address = ids.proxy_addr)
    %}

    // Test that admin has changed
    let (new_admin) = IMockProxy.getAdmin(proxy_addr);
    assert new_admin = 125;

    return ();
}




