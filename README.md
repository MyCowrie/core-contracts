# Cowrie Contracts
Cowrie core contracts. Including ERC20 token, Staking and Vesting.

## Setup
The project is built using the [Truffle](https://trufflesuite.com/docs/truffle/) framework. Following are the steps to setup the project to compile and deploy the contracts.

1. Setup **Truffle** globally

    `npm install -g truffle`

2. Then from the root of project run following command to **install all the dependencies**.

    `npm install`

3. Next, to **flatten** our contract files.
    
    -  Run the flattener from the root of project
    
        `truffle-flattener contracts/<contract name>.sol > <output file name>.sol`
    
    - The flattened files can be found in root directory of project.

4. Next, to deploy the contracts, we are using [Remix IDE](https://remix.ethereum.org/)
    
    - Copy or upload the flattened file on Remix IDE.

    - Setup the compiler with following settings

        - Compiler version `0.8.15+commit.e14f2714`
        - Language `Solidity`
        - EVM Version `default`
        - Check `Enable Optimization` and set it to `200`

    - Compile the contract file and verify that there are no breaking errors.

    - In the environment section, select your connected wallet.

    - Then under contract section, select appropriate contract to be deployed.

    - Then click `Deploy` after inputting the appropriate arguments to the constructor.

## Mainnet Contracts
- COWRIE Token BSC `0xde51d1599339809cafb8194189ce67d5bdca9e9e`
- Staking Contract BSC `0x6191a038155f47ac5c3717f15e62aacd294fd4b4`