// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IInitializer {
    function initialize(bytes memory params) external returns (bool);
}