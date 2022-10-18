# Terminal value contract

This contract stores updates of different values, that are updated by keeper bots, who are incetivized to do this based on the reward assigned by the person from requested the updates. 
Currently only supports rewards in ETH.

## Basic Concept:
    - The main contract stored the updates, request and the logic around it. 
    - To update value, you need to launch the second contract, which basically acts as a middleware, that will contain the function `get_new_value` that will be called by the updaters through the main contract. 
    - Than call the `register_request` function in the main contract, which'll create the request that updaters can read and decide whether they want to keep updating this value(based on the reward amount).

## Usage
    - Look into template_exmaple.cairo in current directory
    - Create contract that contains `get_new_value` function which returns single felt
    - Launch the contract you just created and store it's address
    - Call `register_request` in main contract
    - Wait for expiration and read the terminal value   
