// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBeakerStorageV1 {
    function factory() external view returns (uint256);

    function router() external view returns (uint256);

    function strategy() external view returns (uint256);

    function asset() external view returns (uint256);

    function cap() external view returns (uint256);

    function vaultId() external view returns (uint16);
}

interface IBeakerStorage is IBeakerStorageV1 {}