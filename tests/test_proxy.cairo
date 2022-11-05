%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from tests.mock_proxies.mock_proxy_interface import IMockProxy
from starkware.cairo.common.alloc import alloc


@external
func __setup__{syscall_ptr: felt*, range_check_ptr}(){

    %{
        # Declare all mock proxies
        context.proxy_mock_hash_1 = declare(
            "tests/mock_proxies/mock_proxy_1.cairo"
        ).class_hash

        context.proxy_mock_hash_2 = declare(
            "tests/mock_proxies/mock_proxy_2.cairo"
        ).class_hash        

        context.proxy_mock_hash_3 = declare(
            "tests/mock_proxies/mock_proxy_3.cairo"
        ).class_hash

        context.proxy_mock_hash_4 = declare(
            "tests/mock_proxies/mock_proxy_4.cairo"
        ).class_hash

        # Deploy Proxy contract and set proxy_mock_hash_1 as initial hash
        context.proxy_addr = deploy_contract(
            "contracts/proxy_contract/proxy.cairo",
            [context.proxy_mock_hash_1, 0, 0]
        ).contract_address
    %}

    return ();
}

// Main test for testing the proxy
// Basic description:
//      There are some mock contracts containing DummyStruct
//      Each contract contains the Struct, but with slightly different fields
//      I deploy one contract and try to read the Struct from the storage var,
//      Then upgrade it to some other contract with slightly different Struct and see what happens
//      Repeat several times with varying Structs
@external
func test_proxy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    alloc_locals;

    tempvar proxy_addr;
    %{
        ids.proxy_addr = context.proxy_addr

        # Start pranking the admin address
        stop_address_prank_old = start_prank(124, target_contract_address = ids.proxy_addr)

    %}

    // Init the proxy and assert that admin is the same
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

    %{
        # Write new value to dummy_storage
        store(
            target_contract_address = ids.proxy_addr, 
            variable_name = "dummy_storage",
            value = [99]
        )
        # Write new value to dummy_storage_input 
        store(
            target_contract_address = ids.proxy_addr, 
            variable_name = "dummy_storage_input",
            value = [98],
            key = [1]
        )
        # Write new value to dummy_storage_struct
        store(
            target_contract_address = ids.proxy_addr, 
            variable_name = "dummy_storage_struct",
            value = [97],
            key = [1]
        )
    %}
    
    // Read the values and assert them 
    let (_, res_dummy) = IMockProxy.read_dummy(proxy_addr);
    assert res_dummy[0] = 99;

    let (_, res_input) = IMockProxy.read_dummy_input(proxy_addr, 1);
    assert res_input[0] = 98;

    let (inp) = alloc();
    assert [inp] = 1;
    let (res_struct) = IMockProxy.read_dummy_struct(proxy_addr, 1, inp);
    assert res_struct = 97;


    // Create proxy_addr var again and rename it, due to some memory shenanigans
    tempvar proxy_addr_2;
    tempvar proxy_mock_hash_2;
    %{
        ids.proxy_addr_2 = context.proxy_addr
        ids.proxy_mock_hash_2 = context.proxy_mock_hash_2
    %}

    // Upgrade the contract
    IMockProxy.upgrade(proxy_addr_2, proxy_mock_hash_2);

    // Test that new hash is set
    let (new_hash) = IMockProxy.getImplementationHash(proxy_addr_2);
    assert new_hash = proxy_mock_hash_2;

    // Read old values
    let (_, res_dummy2) = IMockProxy.read_dummy(proxy_addr_2);
    assert res_dummy2[0] = 99;
    assert res_dummy2[1] = 0; // In this case, new field is zero

    let (_, res_input2) = IMockProxy.read_dummy_input(proxy_addr_2, 1);
    assert res_input2[0] = 98;
    assert res_input2[1] = 0; // In this case, new field is zero as well

    // Doesn't work when using Struct as map
    let (inp2) = alloc();
    assert [inp2] = 1;
    assert [inp2 + 1] = 1;
    let (res_struct2) = IMockProxy.read_dummy_struct(proxy_addr_2, 2, inp2);
    assert res_struct2 = 0; // This isn't the original value

    // Write new values to the storage variables
    tempvar prox_addr_3;
    %{
        store(
            target_contract_address = context.proxy_addr,
            variable_name = 'dummy_storage',
            value = [11, 22]
        )
        store(
            target_contract_address = context.proxy_addr,
            variable_name = 'dummy_storage_input',
            value = [33, 44],
            key = [2]
        )
        store(
            target_contract_address = context.proxy_addr,
            variable_name = 'dummy_storage_struct',
            value = [100],
            key = [55, 66]
        )
        ids.prox_addr_3 = context.proxy_addr
    %}

    // Read new values and assert the results
    let (_, res_dummy3) = IMockProxy.read_dummy(prox_addr_3);
    assert res_dummy3[0] = 11;
    assert res_dummy3[1] = 22;

    let (_, res_input3) = IMockProxy.read_dummy_input(prox_addr_3, 2);
    assert res_input3[0] = 33;
    assert res_input3[1] = 44;

    let (inp3) = alloc();
    assert [inp3] = 55;
    assert [inp3 + 1] = 66;
    let (res_struct) = IMockProxy.read_dummy_struct(prox_addr_3, 2, inp3);
    assert res_struct = 100;

    // Upgrade 
    tempvar proxy_mock_hash_3;
    tempvar proxy_addr_4;
    %{
        ids.proxy_mock_hash_3 = context.proxy_mock_hash_3
        ids.proxy_addr_4 = context.proxy_addr
    %}
    IMockProxy.upgrade(proxy_addr_4, proxy_mock_hash_3);

    // Test that new hash is set
    let (new_hash2) = IMockProxy.getImplementationHash(proxy_addr_4);
    assert new_hash2 = proxy_mock_hash_3;

    // Read values and assert results
    let (_, res_dummy4) = IMockProxy.read_dummy(proxy_addr_4);
    assert res_dummy4[0] = 11;
    assert res_dummy4[1] = 22;
    assert res_dummy4[2] = 0; // Again, the new fields are zeros
    assert res_dummy4[3] = 0;
    assert res_dummy4[4] = 0;

    let (_, res_input4) = IMockProxy.read_dummy_input(proxy_addr_4, 2);
    assert res_input4[0] = 33;
    assert res_input4[1] = 44;
    assert res_input4[2] = 0; // Same here
    assert res_input4[3] = 0;
    assert res_input4[4] = 0;

    // Doesn't work when using Struct as mapping key
    let (inp4) = alloc();
    assert [inp4] = 55;
    assert [inp4 + 1] = 66;
    assert [inp4 + 2] = 0;
    assert [inp4 + 3] = 0;
    assert [inp4 + 4] = 0;
    let (res_struct4) = IMockProxy.read_dummy_struct(proxy_addr_4, 5, inp4);
    assert res_struct4 = 0;  // And Struct as mapping key just doesn't work

    // Write new values, now let's test what happens if some field is deleted
    tempvar proxy_addr_5;
    tempvar proxy_mock_hash_4;
    %{
        store(
            target_contract_address = context.proxy_addr,
            variable_name = 'dummy_storage',
            value = [11, 22, 33, 44, 55]
        )

        store(
            target_contract_address = context.proxy_addr,
            variable_name = 'dummy_storage_input',
            value = [111, 222, 333, 444, 555],
            key = [144]
        )
        ids.proxy_mock_hash_4 = context.proxy_mock_hash_4
        ids.proxy_addr_5 = context.proxy_addr
    %}

    // Upgrade to contract with deleted field from DummyStruct
    IMockProxy.upgrade(proxy_addr_5, proxy_mock_hash_4);
    let (new_hash3) = IMockProxy.getImplementationHash(proxy_addr_5);
    assert new_hash3 = proxy_mock_hash_4;

    // Just deletes averything after 
    let (_, res_dummy5) = IMockProxy.read_dummy(proxy_addr_5);
    assert res_dummy4[0] = 11;
    assert res_dummy4[1] = 22;
    assert res_dummy4[3] = 0;
    assert res_dummy4[4] = 0;

    // Then it continues here????
    let (_, res_input5) = IMockProxy.read_dummy_input(proxy_addr_5, 144);
    assert res_input4[0] = 33; 
    assert res_input4[1] = 44;
    assert res_input4[3] = 0;
    assert res_input4[4] = 0;

    %{
        stop_address_prank_new()
    %}

    return ();
}
