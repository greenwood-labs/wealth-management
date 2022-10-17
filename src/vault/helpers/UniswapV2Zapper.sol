// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/IZapper.sol";
import "src/libraries/UniswapV2Lib.sol";
import "src/vault/base/Multicall.sol";
import "src/vault/base/ReentrancyGuard.sol";
import "src/vault/helpers/SwapRouter.sol";

contract UniswapV2Zapper is IZapper, Multicall, ReentrancyGuard, SwapRouter {
    using SafeERC20 for *;

    // solhint-disable no-empty-blocks
    constructor(
        address _governance,
        address _wrappedNative,
        address[] memory _factoryList
    ) SwapRouter(_governance, _wrappedNative, _factoryList) {}

    function zapIn(
        address pair,
        address tokenIn,
        uint256 amountIn,
        address recipient
    ) external payable override unlocked returns (uint256 liquidity) {
        (address token0, address token1) = UniswapV2Lib.pairTokens(pair);

        if (tokenIn != token0 && tokenIn != token1) {
            address target = token0 == wrappedNative ? token0 : token1;
            amountIn = swap(tokenIn, target, amountIn, address(this));
            tokenIn = target;
        } else {
            pull(tokenIn, address(this), amountIn);
        }

        (uint256 reserve0, uint256 reserve1) = UniswapV2Lib.getReserves(
            pair,
            token0,
            token1
        );

        uint256 swapAmount = tokenIn == token0
            ? UniswapV2Lib.getAmountToSwap(amountIn, reserve0)
            : UniswapV2Lib.getAmountToSwap(amountIn, reserve1);

        uint256 amountOut = UniswapV2Lib.getAmountOut(
            swapAmount,
            tokenIn == token0 ? reserve0 : reserve1,
            tokenIn == token0 ? reserve1 : reserve0
        );

        tokenIn.safeTransfer(pair, swapAmount);

        IUniswapV2Pair(pair).swap(
            tokenIn == token0 ? 0 : amountOut,
            tokenIn == token0 ? amountOut : 0,
            address(this),
            new bytes(0)
        );

        (uint256 amount0, uint256 amount1) = UniswapV2Lib
            .getAcceptableLiquidity(
                pair,
                token0,
                token1,
                token0.getBalanceOf(address(this)),
                token1.getBalanceOf(address(this))
            );

        token0.safeTransfer(pair, amount0);
        token1.safeTransfer(pair, amount1);

        liquidity = IUniswapV2Pair(pair).mint(recipient);

        uint256 leftover = tokenIn.getBalanceOf(address(this));

        if (leftover != 0) pay(tokenIn, address(this), recipient, leftover);
    }

    function zapOut(
        address pair,
        address tokenOut,
        uint256 liquidity,
        address recipient
    ) external override unlocked returns (uint256 amountOut) {
        pull(pair, address(this), liquidity);

        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(
            address(this)
        );

        (address token0, address token1) = UniswapV2Lib.pairTokens(pair);

        if (tokenOut == token0) {
            swap(token1, token0, amount1, address(this));
        } else if (tokenOut == token1) {
            swap(token1, token1, amount0, address(this));
        } else {
            swap(token0, tokenOut, amount0, address(this));
            swap(token1, tokenOut, amount1, address(this));
        }

        amountOut = tokenOut.getBalanceOf(address(this));

        tokenOut.safeTransfer(recipient, amountOut);
    }
}
