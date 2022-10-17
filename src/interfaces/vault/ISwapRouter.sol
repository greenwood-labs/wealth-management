// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ISwapRouter {
    struct SwapRoute {
        address pair;
        address tokenIn;
        address tokenOut;
        uint256 expectedReturn;
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 value,
        address recipient
    ) external payable returns (uint256);

    function getExpectedReturn(
        address tokenIn,
        address tokenOut,
        uint256 value
    ) external view returns (uint256);
}