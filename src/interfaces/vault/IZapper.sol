// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IZapper {
    // enum LPType {
    //     UNISWAP_V2,
    //     CURVE_POOL
    // }

    function zapIn(
        // LPType lpType,
        address pool,
        address tokenIn,
        uint256 amountIn,
        address recipient
    ) external payable returns (uint256);

    function zapOut(
        // LPType lpType,
        address pool,
        address tokenOut,
        uint256 liquidity,
        address recipient
    ) external returns (uint256);
}