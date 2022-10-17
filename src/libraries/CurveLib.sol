// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "src/interfaces/Curve/ICurve.sol";
import "./FixedPoint.sol";

library CurveLib {
    using FixedPoint for uint256;

    uint256 private constant PERCENTAGE_FACTOR = 10000;

    function addLiquidity(
        ICurvePool pool,
        bool useUnderlying,
        uint256 length,
        uint256 tokenId,
        uint256 value,
        uint256 minAmountOut
    ) internal {
        require(value != 0, "!0");

        if (length == 2) {
            uint256[2] memory amounts;
            amounts[tokenId] = value;

            if (useUnderlying)
                pool.add_liquidity(amounts, minAmountOut, useUnderlying);
            else pool.add_liquidity(amounts, minAmountOut);
        } else if (length == 3) {
            uint256[3] memory amounts;
            amounts[tokenId] = value;

            if (useUnderlying)
                pool.add_liquidity(amounts, minAmountOut, useUnderlying);
            else pool.add_liquidity(amounts, minAmountOut);
        } else if (length == 4) {
            uint256[4] memory amounts;
            amounts[tokenId] = value;

            if (useUnderlying)
                pool.add_liquidity(amounts, minAmountOut, useUnderlying);
            else pool.add_liquidity(amounts, minAmountOut);
        } else if (length == 5) {
            uint256[5] memory amounts;
            amounts[tokenId] = value;

            if (useUnderlying)
                pool.add_liquidity(amounts, minAmountOut, useUnderlying);
            else pool.add_liquidity(amounts, minAmountOut);
        } else revert("invalid tokens length");
    }

    function removeLiquidity(
        ICurvePool pool,
        bool useUnderlying,
        uint256 tokenId,
        uint256 value,
        uint256 minAmountOut
    ) internal {
        require(value != 0, "!0");

        if (useUnderlying)
            pool.remove_liquidity_one_coin(
                value,
                toInt128(tokenId),
                minAmountOut,
                useUnderlying
            );
        else
            pool.remove_liquidity_one_coin(
                value,
                toInt128(tokenId),
                minAmountOut
            );
    }

    function swap(
        ICurvePool pool,
        bool useUnderlying,
        uint256 tokenInId,
        uint256 tokenOutId,
        uint256 value
    ) internal {
        int128 i = toInt128(tokenInId);
        int128 j = toInt128(tokenOutId);

        uint256 minAmountOut = _computeAmountOut(
            useUnderlying,
            pool,
            i,
            j,
            value
        );

        if (!useUnderlying) pool.exchange(i, j, value, minAmountOut);
        else pool.exchange_underlying(i, j, value, minAmountOut);
    }

    function computeAmountOut(
        ICurvePool pool,
        bool useUnderlying,
        uint256 tokenInId,
        uint256 tokenOutId,
        uint256 value
    ) internal view returns (uint256) {
        return
            _computeAmountOut(
                useUnderlying,
                pool,
                toInt128(tokenInId),
                toInt128(tokenOutId),
                value
            );
    }

    function _computeAmountOut(
        bool useUnderlying,
        ICurvePool pool,
        int128 i,
        int128 j,
        uint256 dx
    ) internal view returns (uint256) {
        if (!useUnderlying) return pool.get_dy(i, j, dx);
        else return pool.get_dy_underlying(i, j, dx);
    }

    function convertToLP(
        ICurvePool pool,
        uint8 length,
        uint256 tokenId,
        uint256 value,
        uint256 slippage
    ) internal view returns (uint256) {
        if (value == 0) return 0;

        if (length == 2) {
            uint256[2] memory amounts;
            amounts[tokenId] = value;

            return
                computeValueAfterSlippage(
                    pool.calc_token_amount(amounts, true),
                    slippage
                );
        } else if (length == 3) {
            uint256[3] memory amounts;
            amounts[tokenId] = value;

            return
                computeValueAfterSlippage(
                    pool.calc_token_amount(amounts, true),
                    slippage
                );
        } else if (length == 4) {
            uint256[4] memory amounts;
            amounts[tokenId] = value;

            return
                computeValueAfterSlippage(
                    pool.calc_token_amount(amounts, true),
                    slippage
                );
        } else if (length == 5) {
            uint256[5] memory amounts;
            amounts[tokenId] = value;

            return
                computeValueAfterSlippage(
                    pool.calc_token_amount(amounts, true),
                    slippage
                );
        } else revert("invalid tokens length");
    }

    function convertToUnderlying(
        ICurvePool pool,
        uint256 tokenId,
        uint256 value
    ) internal view returns (uint256) {
        if (value == 0) return 0;

        return pool.calc_withdraw_one_coin(value, toInt128(tokenId));
    }

    function pricePerShare(ICurvePool pool) internal view returns (uint256) {
        return pool.get_virtual_price();
    }

    function computeValueAfterSlippage(uint256 value, uint256 slippage)
        private
        pure
        returns (uint256)
    {
        if (slippage == 0) return value;

        return
            (PERCENTAGE_FACTOR - slippage).mulDivDown(value, PERCENTAGE_FACTOR);
    }

    function toInt128(uint256 y) private pure returns (int128 z) {
        require(
            y < 2**255 && (z = int128(int256(y))) == int256(y),
            "SafeCast failed"
        );
    }
}
