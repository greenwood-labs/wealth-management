// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBeakerPeriodicVault {
    function keeper() external returns (address);

    function totalAssets() external view returns (uint256);
    function accountShares(address account) external view returns (uint256);
    function shareBalances(address account) external view returns (uint256, uint256);

    function deposit(uint256 assets) external;

    function initiateRedeem(uint256 shares) external;
    function redeem() external;

    function withdraw(uint256 assets) external;

    function claimShares(uint256 shares) external;

    function rollToNextPosition() external;
    function commitAndClose() external;
}