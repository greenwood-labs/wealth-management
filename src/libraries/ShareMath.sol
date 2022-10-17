// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./Periodic.sol";

library ShareMath {

    /// @notice converts an amount of assets to shares based on the conversion rate
    /// @param assetAmount amount of assets to convert
    /// @param assetPerShare exchange rate between the asset and the BLP token
    /// @param decimals decimals of the asset
    /// @return Shares amount of shares based on the amount of assets given
    function assetToShares(
        uint256 assetAmount,
        uint256 assetPerShare,
        uint256 decimals
    ) internal pure returns (uint256) {

        // make sure roundPricePerShare[currentRound] has been set
        require(assetPerShare > 0, "Invalid assetPerShare");

        return assetAmount * (10 ** decimals) / assetPerShare;
    }

    /// @notice converts an amount of shares to assets based on the conversion rate
    /// @param shares amount of shares to convert
    /// @param assetPerShare exchange rate between the asset and the BLP token
    /// @param decimals decimals of the asset
    /// @return Assets amount of shares assets on the amount of shares given
    function sharesToAssets(
        uint256 shares,
        uint256 assetPerShare,
        uint256 decimals
    ) internal pure returns (uint256) {

        // make sure roundPricePerShare[currentRound] has been set
        require(assetPerShare > 0, "Invalid assetPerShare");

        return shares * assetPerShare / (10 ** decimals);
    }

    /// @notice Returns the shares unredeemed by the user given a Deposit
    /// @param deposit the user's deposit
    /// @param currentRound the current round of the beaker
    /// @param assetPerShare exchange rate between the asset and the BLP token
    /// @param decimals decimals of the asset
    /// @return unredeemedShares the balance of shares that are owed
    function getSharesFromDeposit(
        Periodic.Deposit memory deposit,
        uint256 currentRound,
        uint256 assetPerShare,
        uint256 decimals
    ) internal pure returns (uint256) {

        uint256 unclaimedShares = deposit.unclaimedShares;

        if (deposit.round > 0 && deposit.round < currentRound) {
            uint256 sharesFromRound = assetToShares(deposit.amount, assetPerShare, decimals);

            unclaimedShares += sharesFromRound;
        } 

        return unclaimedShares;
    }

    /// @notice calculate share price using underlying assets that arent currently schedule for deposit
    /// @param totalSupply total amount of BLP shares that are in circulation
    /// @param totalBalance total amount of underlying assets
    /// @param pendingDepositAmount amount of underlying assets in the contract, but pending a deposit into the strategy
    /// @param decimals decimals of the underlying asset
    /// @return pricePerShare the price in the underlying asset per share
    function pricePerShare(
        uint256 totalSupply,
        uint256 totalBalance,
        uint256 pendingDepositAmount, 
        uint256 decimals
    ) internal pure returns (uint256) {

        uint256 singleShare = 10 ** decimals;

        return totalSupply > 0
            ? singleShare * (totalBalance - pendingDepositAmount) / totalSupply
            : singleShare;
    }
}