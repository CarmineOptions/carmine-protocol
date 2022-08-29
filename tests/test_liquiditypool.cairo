%lang starknet

from interface_lptoken import ILPToken

@external
func __setup__():
    %{ 
    context.main_addr = deploy_contract("./contracts/liquidity_pool.cairo", # totally not clear how to deploy a contract that spans multiple files
        {
    }).contract_address
    context.lpt_addr = deploy_contract("./contracts/lptoken.cairo", 
        { "name": "LPToken", "symbol": "LPT", "decimals": 18, "initial_supply": 0}) }
    }).contract_address 
    %}
    return ()
end

func test_initialization{syscall_ptr : felt*, range_check_ptr}():
    let (symbol) = ILPToken.symbol(contract_address=context.lpt_addr)
    assert symbol = 'LPT'
    return ()
end

# tests don't work yet, will be fixed in the future