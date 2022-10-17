// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./ShareMath.sol";

library Periodic {

    /// @param round current round number
    /// @param lockedAssets amount of underlying funds locked
    /// @param totalPendingDeposits total pending underlying funds that have yet to mint BLP tokens
    /// @param sharesQueuedForRedemption amount of shares locked for redemption
    /// @param assetsUnlockedForRedemption amount of assets unlocked for redemption from the previous round
    /// @param roundExpiration timestamp of when the current round will expire
    struct StrategyState {
        uint256 round;
        uint256 lockedAssets;
        uint256 totalPendingDeposits;
        uint256 sharesQueuedForRedemption;
        uint256 assetsUnlockedForRedemption;
        uint256 roundExpiration;
    }

    /// @param decimals decimals of the asset
    /// @param totalBalance total balance of the underlying asset
    /// @param currentShareSupply current minted supply of BLP tokens
    struct RolloverParams {
        uint256 decimals;
        uint256 totalBalance;
        uint256 currentShareSupply;
    }

    /// @param round round number of the deposit
    /// @param amount deposit amount
    /// @param unclaimedShares unclaimed shares balance
    struct Deposit {
        uint256 round;
        uint256 amount;
        uint256 unclaimedShares;
    }

    /// @param round round number of the redemption
    /// @param shares number of shares redeemed
    struct Redemption {
        uint256 round;
        uint256 shares;
    }

    /// @notice calculates values for the rollover process
    /// @param strategyState current state of the beaker
    /// @param rolloverParams parameters for the rollover calculation
    /// @return newLockedAssets amount of funds to be locked in the next round
    /// @return assetsUnlockedForRedemption amount of funds set aside for users to redeem
    /// @return newPricePerShare the new price per BLP for the round
    /// @return sharesToMint amount of shares to mint from deposits
    function calculateRolloverValues(
        StrategyState storage strategyState, 
        RolloverParams calldata rolloverParams
    ) 
        external 
        view 
        returns (
            uint256 newLockedAssets,
            uint256 assetsUnlockedForRedemption,
            uint256 newPricePerShare,
            uint256 sharesToMint
        )
    {
        // calculate the new price per share of the BLP token
        newPricePerShare = ShareMath.pricePerShare(
            rolloverParams.currentShareSupply, 
            rolloverParams.totalBalance, 
            strategyState.totalPendingDeposits, 
            rolloverParams.decimals
        );

        // the amount of new shares to mint. Because the deposited funds from last round
        // can increase or decrease, we ensure that newly minted shares do not take on that
        // gain or loss
        sharesToMint = ShareMath.assetToShares(
            strategyState.totalPendingDeposits, 
            newPricePerShare, 
            rolloverParams.decimals
        );

        // the new total supply of BLP shares
        uint256 newShareSupply = rolloverParams.currentShareSupply + sharesToMint;

        // convert queued redemption shares to the total queued redemption amount of the underlying asset
        assetsUnlockedForRedemption = newShareSupply > 0
            ? ShareMath.sharesToAssets(strategyState.sharesQueuedForRedemption, newPricePerShare, rolloverParams.decimals)
            : 0;

        // the total underlying balance minus the underlying assets reserved for redemptions
        newLockedAssets = rolloverParams.totalBalance - assetsUnlockedForRedemption;

        return (
            newLockedAssets,
            assetsUnlockedForRedemption,
            newPricePerShare,
            sharesToMint
        );
    }  
}