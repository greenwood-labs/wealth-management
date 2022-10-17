// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract BeakerStorageV1 {
    /************************************************
     *  STORAGE
     ***********************************************/

    /// @notice ID of the beaker
    uint16 public vaultId;

    /// @notice address of the beaker factory
    address public factory;

    /// @notice router address for swapping tokens
    address public router;

    /// @notice Role in charge of admin tasks and emergency functions
    address public owner;

    /// @notice strategy address for the beaker
    address public strategy;

    /// @notice maximum capacity of the strategy
    uint256 public cap;
}

// solhint-disable-next-line no-empty-blocks
abstract contract BeakerStorage is BeakerStorageV1 {

}
