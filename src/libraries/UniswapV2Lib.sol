// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "src/interfaces/Uniswap/IUniswapV2.sol";
import "./FixedPoint.sol";

library UniswapV2Lib {
    function swap(
        address pair,
        address srcToken,
        address dstToken,
        uint256 amountIn,
        address recipient
    ) internal returns (uint256 amountOut) {
        (uint256 reserveIn, uint256 reserveOut) = getReserves(
            pair,
            srcToken,
            dstToken
        );

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);

        (address token0, ) = sortTokens(srcToken, dstToken);

        (uint256 amountOut0, uint256 amountOut1) = srcToken == token0
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));

        IUniswapV2Pair(pair).swap(
            amountOut0,
            amountOut1,
            recipient,
            new bytes(0)
        );
    }

    function getAcceptableLiquidity(
        address pair,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal view returns (uint256 amountAIn, uint256 amountBIn) {
        (uint256 reserveA, uint256 reserveB) = getReserves(
            pair,
            tokenA,
            tokenB
        );

        if (reserveA == 0 && reserveB == 0) {
            (amountAIn, amountBIn) = (amountA, amountB);
        } else {
            uint256 amountBOptimal = quote(amountA, reserveA, reserveB);
            if (amountBOptimal <= amountB) {
                (amountAIn, amountBIn) = (amountA, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountB, reserveB, reserveA);
                require((amountAOptimal <= amountA), "insufficient liquidity");

                (amountAIn, amountBIn) = (amountAOptimal, amountB);
            }
        }
    }

    function getAmountToSwap(uint256 amountIn, uint256 reserveIn)
        internal
        pure
        returns (uint256)
    {
        return
            (FixedPoint.sqrt(
                reserveIn * (amountIn * 3988000 + reserveIn * 3988009)
            ) - (reserveIn * 1997)) / 1994;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256) {
        if (amountIn == 0 || reserveIn == 0 || reserveOut == 0) return 0;

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        if (amountOut == 0 || reserveIn == 0 || reserveOut == 0) return 0;

        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        if (amountA == 0 || reserveA == 0 || reserveB == 0) return 0;

        amountB = (amountA * reserveB) / reserveA;
    }

    function getReserves(
        address pair,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();

        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    function pairTokens(address pair)
        internal
        view
        returns (address token0, address token1)
    {
        (token0, token1) = (
            IUniswapV2Pair(pair).token0(),
            IUniswapV2Pair(pair).token1()
        );
    }

    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (address) {
        return IUniswapV2Factory(factory).getPair(tokenA, tokenB);
    }

    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address, address)
    {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
