# Greenwood
<p align="center"> 
    <img 
        src="https://user-images.githubusercontent.com/8098163/193351307-ad2a47e2-59ce-408e-b9b6-fb08bff6b66b.png"
        alt="Greenwood" 
        height="70%"
        width="100%">
</p>

## Introduction
Greenwood is a non-custodial wealth management protocol for Web3. With Greenwood, wealth managers can give their clients access to the long tail of decentralized finance (DeFi) assets and protocols for the first time.

Today, wealth managers can’t offer their clients meaningful exposure to DeFi for two main reasons. First, qualified custodians do not custody most DeFi tokens so wealth managers are limited to purchasing DeFi governance tokens for their clients in discretionary accounts. Second, multisignature (multisig) wallets that can custody most DeFi tokens are too cumbersome for wealth managers and too complicated for their clients to use.

The Greenwood protocol fixes these problems by optimizing Gnosis Safe multisig wallets using Gnosis Modules, developing automated vaults and protocol adapters to improve multisig UX, and wrapping these contracts in an easy to use interface that is optimized for wealth management user flows.

This document provides a high-level overview of the Greenwood protocol.


## Motivation
Keeping up with DeFi is a full-time job. We believe that in the near future the majority of DeFi TVL will originate with wealth managers who ingest an investors financial goals, translate those goals into a financial plan, and map that financial plan to a personalized token portfolio. Wealth managers are the dominant distribution channel for financial products and we posit that the same motivations that drive the trillion-dollar wealth management industry in traditional finance (convenience, lack of expertise, etc.) will carry over to DeFi as the DeFi ecosystem goes multichain and grows in complexity. 

Wealth managers need infrastructure and tooling to service the growing appetite for DeFi exposure in client portfolios.

Our mission at Greenwood Labs is to accelerate the world’s transition to a more just financial system. Permissionless, decentralized, non-custodial wealth management infrastructure for Web3 is a step towards realizing that mission.

## How it Works
Greenwood can be conceptualized as three layers: the interface layer, multisig layer, and vault layer.
<p align="center"> 
    <img 
        src="https://user-images.githubusercontent.com/8098163/193351590-5b1cb203-cdfb-4155-8658-ef09d4433d46.jpg"
        alt="Greenwood Stack" 
        height="70%"
        width="50%">
</p>

### Greenwood Interface
The Greenwood interface provides a clean and friendly way of interacting with the Greenwood Multisig and Greenwood Vaults. Our design goal with this interface was to develop intuitive user flows and fuse the trustworthy, authoritative, feelings of traditional finance with the modern, ergonomic, feeling of FinTech. We are currently in the process of developing both desktop and mobile views for our interface in Javascript using the React.js framework. Along with React, we’re using (or planning to use) a number of other tools to improve performance and censorship-resilience. Some of the other components of the Greenwood frontend include:

- [WAGMI](https://wagmi.sh): A React hooks library simplifying Web3 related actions in the frontend (wallet connections, contract calls, etc). This library helps to speed up and simplify our frontend development experience.
- [The Graph](https://thegraph.com/en/): An indexing protocol to query on-chain data with GraphQL using open APIs called ‘subgraphs’. This tool provides a better user experience when loading large amounts of data from our protocol.
- [IPFS](https://ipfs.io/): Peer-to-peer, censorship resistant network for hosting files. This tool allows us to deploy mirrors of our frontend app so we are not forced to rely on centralized hosting solutions.
- [Radicle](https://radicle.xyz/): Open-source Github alternative. This tool is a decentralized network that allows developer teams to collaborate without needing a third party. We are currently using radicle to coordinate backups of code releases.

<p align="center"> 
    <img 
        src="https://user-images.githubusercontent.com/8098163/193360551-23804319-056b-4a4d-9f55-e5f66f78eb8c.png"
        alt="Interface Views" 
        height="60%"
        width="80%">
</p>

### Greenwod Multisig
#### Overview
Greenwood builds upon the battle-tested Gnosis Safe Vault multisignature wallet contracts. We optimize Gnosis Vaults for the wealth management use case through the inclusion of a Greenwood specific Gnosis Module. This Module contract allows clients to bypass the traditional multisig threshold requirement in a single transaction and prevents the addition of Vault owners/signers. You can read more about Gnosis Safe Modules [here](https://docs.gnosis-safe.io/contracts/modules-1) and [here](https://help.gnosis-safe.io/en/articles/4934378-what-is-a-module).

#### Greenwood Gnosis Module
The Module proxy contract is deployed and the Gnosis Vault enables the Module upon instantiation. Then, the Module contract can make calls to the Gnosis Vault via `execTransactionFromModule()`. Because the Gnosis Vault enabled the module, the execution of the `calldata` can be performed on the Gnosis Vault without requiring a threshold of signers to be met. The implementation of the Module can then add on its own custom functionality as a layer on top of the Gnosis Vault.
<p align="center"> 
    <img 
        src="https://user-images.githubusercontent.com/8098163/193352002-ce32eb9a-9a82-4bca-8b8e-07a21de3ecd4.png"
        alt="Module Diagram" 
        height="70%"
        width="100%">
</p>

### Greenwood Vaults
#### Overview
Greenwood vaults exist as wrappers around multi-step DeFi operations and specific investment strategies implemented in a Strategy contract in order to improve multisig UX and allow for non-discretionary advisors to access actively managed investment strategies. Greenwood vaults continually invest and reinvest deposited funds without requiring user interaction. Greenwood vault depositors receive an ERC20 LP token which can be used to redeem deposited funds. Greenwood vaults are deployed from a Factory contract. There are two types of Greenwood vaults:
- Periodic Vault
- Perpetual Vault

#### Periodic Vaults
- BeakerPeriodicVault.sol
- ERC4626-like
- Rely on a keeper to roll the vault into the next period
- Deposits and withdrawals subject to delay until the next period rolls over

<p align="center"> 
    <img 
        src="https://user-images.githubusercontent.com/8098163/193356827-608ac009-2b80-4333-b710-81a0e1d2ce3f.png"
        alt="Periodic Diagram" 
        height="70%"
        width="100%">
</p>

##### Periodic Vault Round Flow
Periodic vaults operate in specifically defined round cadence. For example, a period vault will execute a rolling strategy on a weekly or monthly basis. During a round, the vault can accept two signals from users: a signal to deposit funds when the next round begins, or a signal to withdraw funds when the next round begins. At the conclusion of a round, the vault will sweep in the funds awaiting inclusion into the next round, and it will payout (via burning of LP tokens) the users that signaled the withdrawal of their funds. Once these funds have been settled, the remaining funds in the vault are reinvested into the strategy contract. 

For most periodic strategies, a privileged keeper account will be used to manually call the `rollToNextPosition()` function to reinvest the funds into the strategy. This will mark the initiation of a new period for the vault. At the close of the period, the keeper account will be able to call `commitAndClose()` which will signal the closure of the current period.

##### Periodic Vault User Flow
Periodic vaults sweep funds into active management upon the rollover from one investment period to the next. In order to be included in the next investment period, a user will deposit funds via a `deposit()` call on the vault. These funds will not be included in the strategy right away, and can be withdrawn in full at any time before the vault rolls over into the next period via a `withdraw()` call.

Once a vault rolls over into the next round, deposited funds will be swept into the investment strategy for the current period and all periods following until the user decides to indicate their desire to redeem their funds. To do so, a user will make a call via the `initiateRedeem()` function which will tell the vault to set aside the user’s portion of funds once the current period completes. Upon completion of the period, the user’s pro-rata funds will be set aside and not included in the next round and can be redeemed at any time via a call to `redeem()`.

#### Perpetual Vaults
- BeakerVault.sol
- Fully ERC4626 compliant
- Run without needing a keeper
- Deposit and withdraw funds at any time

<p align="center"> 
    <img 
        src="https://user-images.githubusercontent.com/8098163/193357310-24242a86-f1d2-4834-a7b3-72ece52845a3.png"
        alt="Perpetual Diagram" 
        height="70%"
        width="100%">
</p>

##### Perpetual vault user flow
Perpetual vaults do not have a notion of a round or a period, and so, they can be freely deposited into or withdrawn from at anytime without a lockup period. To invest funds, a user will make a call via `deposit()` which will include funds into the strategy contract and in turn the vault will transfer the user LP tokens to be used for pro-rata redemption at a later time.

To withdraw funds from the vault, the user can make a call to `redeem()` to burn the LP token and receive a pro-rata share of the funds under management in the strategy.

#### Strategies
Greenwood vaults exist as generic containers around Strategy contracts. Strategy contracts are meant to implement a single investment strategy or multi-step DeFi action. Generally, strategy contract functions are only called by Greenwood vaults or by privileged Greenwood keeper accounts. 

##### Example Periodic Strategy: Uncapped Buffered Return Enhanced Note Strategy on Opyn
<p align="center"> 
    <img 
        src="https://user-images.githubusercontent.com/8098163/193364372-40c14a12-2425-4d27-ba98-e68c37936e7c.png"
        alt="Factory Diagram" 
        height="70%"
        width="100%">
</p>

The flow for a single round of this strategy works as follows:
1. oToken Creation
    * Strike prices, expiry date, counter-party, and collateral are all specified. This results in the creation of 3 new oTokens (long call, long put, short put).

2. Roll to next position
    * Once oTokens have been created, the collateral is used to fund the oToken vaults and issue oTokens accordingly. In the strategy, WETH is used as collateral to mint long call oTokens which are sold by the counter-party and bought by the strategy. USDC is used as collateral to mint long put oTokens which are sold by the counter-party and bought by the strategy. Finally, the long put oTokens are then used as collateral to mint short put tokens which are sold by the strategy and bought by the counter-party.

3. Commit and close
    * Upon the expiry of all 3 oTokens, the strategy settles the short put oToken vault, retrieving any collateral that will not be redeemed by the counter party. The strategy then redeems long call oTokens for WETH if the oToken expired ITM.
oToken addresses, collateral amounts, and expiry timestamp are all deleted from the contract until a new round begins.

#### Factory
Because both periodic vaults and perpetual vaults were designed to be generic containers around strategy contracts, a minimal proxy deployment pattern is used to deploy implementations of both the vault and strategy contracts, since there is an expectation that the same strategy will be desired for multiple assets.

Template contract addresses for Vaults and Strategies are deployed and then registered via an `id` to the Factory contract. Functions such as `deployVault(vaultID, vaultParams)` and `deployStrategy(strategyID, strategyParams)` can be called to deploy a minimal proxy instance of the vault or strategy using the desired parameters to instantiate the vault.

<p align="center"> 
    <img 
        src="https://user-images.githubusercontent.com/8098163/193356375-e783693a-1f40-4fbe-86d2-5676f5e710d6.png"
        alt="Factory Diagram" 
        height="70%"
        width="100%">
</p>
