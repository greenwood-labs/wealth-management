// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBeakerManager {
    function registry() external view returns (address);

    function getProtocol(uint256 id) external view returns (address);

    function numProtocols() external view returns (uint256);
}