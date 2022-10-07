# Cowrie Contracts
Cowrie core contracts. Including ERC20 token, Staking and Vesting.

## Setup

1. Setup **[Truffle](https://trufflesuite.com/docs/truffle/)** globally

    `npm install -g truffle`

2. Then from the root of project run following command to **install all the dependencies**.

    `npm install`

3. Install **[ganache cli](https://www.npmjs.com/package/ganache)** globally

    `npm i -g ganache`

## Deployment

<details open>
    <summary>Truffle way</summary>

  1. Copy `.env.example` file and rename it to `.env`

        `mv .env.example .env`

  2. Set the value of variables mentioned in `.env` file.

  3. Start `ganache cli` for local deployment and testing.

  4. At last, run following command to deploy the contracts

        `truffle migrate --network <network name>`
</details>

<details>
    <summary>Or using Remix IDE</summary>

  1. Next, to **flatten** our contract files.

      - Run the flattener from the root of project

          `truffle-flattener contracts/<contract name>.sol > <output file name>.sol`

      - The flattened files can be found in root directory of project.

  2. Next, to deploy the contracts, we are using [Remix IDE](https://remix.ethereum.org/)

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
</details>

<br>

## Mainnet Contracts (Binance Smart Chain and Ethereum)
- COWRIE Token `0xde51d1599339809cafb8194189ce67d5bdca9e9e`
- Staking Contract `0x6191a038155f47ac5c3717f15e62aacd294fd4b4`

<br>

# Technical Description

## COWRIE Token
The token is a simple BEP20 standard following contract. It has capped supply of **1,397,255,459** and can only be minted by the Vesting contract only throughout the vesting period and as long as the supply has reached the limit.

## Vesting
Vesting is a certain number of Cowrie that are held aside for some period for the team, partners, advisors, and others who are contributing to the development of the project. 
The Smart contract locks a certain amount of funds until contract conditions are met which will be gradually released once a year, during the project process for financial purposes. In general terms, the process of releasing these coins is called vesting. 
Vesting is used to show that the team is highly interested in the project and will continue working on project development. 
Additionally, vesting lowers market price manipulations.
The Cowrie is built on 2 Vesting methods, **basic yearly vesting** and **AMM SAPD Officer**.

## AMM SAPD Officer

Our SADP is our IBCO type of smart contract coded to look after a healthy release of the some of the vesting wallets.
Total of 55% of annual Cowrie will be managed by the SAPD smart contract.

### How the release %’s work 
We are using `if/then` range logic to determine the number of tokens to be released. 
We set a range of Rise/Fall % and for each range we set the % of tokens to release from the amount decided for that specific month.
The price will be found via API and bot calling from most of the sources in the market like CEX and DEX price movements monthly and the average will determine the `release token %` call.
If the price rises more than +>100%, then we use the highest range's release % which is never more than 30%

    Releasing less % of tokens as the price rises ensures that the beneficiary does not get to Dump 100% of his decided (for that month) tokens. Which further make sure that the market does not go down or gets a long red candle.

**If** demand takes price 
+100% 
**then** we can release max 30% of the total annual wallet %

**If** demand takes price 
80 - 99% 
**then** we can release max 20% of the total annual wallet %

**If** demand takes price 
61% - 79%
**then** we can release max 10% of the total annual wallet %

**If** demand takes price 
51% - 59%
**then** we can release max 5% of the total annual wallet %

**If** the month is less than 50% and below negative -% growth
**Then** we don't release anything that month and it carries over to next month.

**If** for bear markets and less than 50% growth for many numbers of months 
**then** we don’t release any %’s and it keeps on carrying over to next month and so on.

## Staking
Staking gives the holders power to earn rewards on their COWRIE holdings. The Cowrie Staking is the process of delegating or locking up your Cowrie holdings to earn annual Cowrie returns/rewards also known as APY (Annual percentage yield).
The Staking contract from have following functionalities:

- Make various staking pools of different APY, period, and the limitation of how many COWRIEs can be staked under that pool.
- Fund those pools with COWRIE by the Admin of contract. Admin is defined by `DEFAULT_ADMIN_ROLE` of `openzeppelin/AccessControl.sol` and have all the exclusive controls of the contract.
- The stakers must have sufficient(set by `minStake` and `maxStake`) COWRIE tokens to `deposit` in a pool.

      The stakers can withdraw their staked COWRIE anytime. If the withdrawal is done before the end of Pool period, then the staker does not get any rewarding COWRIE and it is transferred directly to the 'companyWallet'.

- There are two ways to stake into a pool, one is using `deposit` function, where the stakers can themselves stake their tokens and get the rewards.
The other way is by calling `depositFor` from any COWRIE holder in the name of any other address. In second case, the rewards are sent to the receiver address COWRIE holder has set, but at the time of cancelling the holder gets back their tokens and receiver does not receive any tokens.