// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/IBaseStrategy.sol";

interface IPeriodicStrategy is IBaseStrategy {
    function period() external view returns (uint256);
    function strategyState() external view returns (
        uint256 round,
        uint256 lockedAssets,
        uint256 totalPendingDeposits,
        uint256 sharesQueuedForRedemption,
        uint256 assetsUnlockedForRedemption,
        uint256 roundExpiration
    );
    function deposits(address account) external view returns (
        uint256 round,
        uint256 amount,
        uint256 unredeemedShares
    );
    function redemptions(address account) external view returns (
        uint256 round,
        uint256 shares
    );
    function roundPricePerShare(uint256 round) external view returns (uint256);
    
    function totalBalance() external view returns (uint256);
    function accountShares(address account) external view returns (uint256);
    function shareBalances(address account) external view returns (uint256, uint256);
    
    function deposit(uint256 assets, address to) external;
    function initiateRedeem(uint256 shares, address to) external returns (uint256);
    function redeem(address to) external returns (uint256, uint256);
    function withdraw(uint256 assets, address to) external;
    function claimShares(uint256 shares, address to) external returns (uint256);
    function rollToNextPosition() external returns (uint256);
    function commitAndClose() external;
}