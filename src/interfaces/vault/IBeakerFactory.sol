// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBeakerFactory {
    function protocolId() external view returns (uint256);

    function getVault(uint256 id) external view returns (address);

    function getStrategy(uint256 id) external view returns (address);

    function numVaults() external view returns (uint256);

    function numStrategies() external view returns (uint256);
}