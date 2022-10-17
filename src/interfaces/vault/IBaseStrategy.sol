// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBaseStrategy {
    function beaker() external returns (address);
    function asset() external returns (address);
    function wrappedNative() external returns (address);
    function migrate(address _strategy) external;
    function setBeaker(address _beaker) external;
}