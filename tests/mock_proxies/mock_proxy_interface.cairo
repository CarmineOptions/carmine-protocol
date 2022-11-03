%lang starknet

@contract_interface
namespace IMockProxy {
    func read_dummy() -> (res_len: felt, res: felt*){
    }

    func read_dummy_input(input: felt) -> (res_len: felt, res: felt*) {
    }

    func read_dummy_struct(input_len: felt, input: felt*) -> (res: felt){
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