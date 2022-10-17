// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/ISwapRouter.sol";
import "src/libraries/UniswapV2Lib.sol";
import "src/vault/base/Governed.sol";
import "src/vault/base/Payment.sol";

contract SwapRouter is ISwapRouter, Governed, Payment {
    using SafeERC20 for address;

    // the address of Uniswap V2 factories
    address[] internal factoryList;

    constructor(
        address _governance,
        address _wrappedNative,
        address[] memory _factoryList
    ) Governed(_governance) Payment(_wrappedNative) {
        factoryList = _factoryList;
    }

    /// @notice Performs the entire swaps with given value of token in for as much as possible of token out
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 value,
        address recipient
    ) public payable override returns (uint256) {
        require(value != 0, "!0");

        if (tokenIn == tokenOut) return value;

        SwapRoute[] memory routes = _setRoutes(tokenIn, tokenOut, value);
        uint256 length = routes.length;
        SwapRoute memory route;

        pull(tokenIn, routes[0].pair, value);

        for (uint256 i; i < length; ) {
            route = routes[i];

            _swap(
                route.pair,
                route.tokenIn,
                route.tokenOut,
                route.expectedReturn,
                i < length - 1 ? routes[i + 1].pair : recipient
            );

            unchecked {
                i = i + 1;
            }
        }

        return routes[routes.length - 1].expectedReturn;
    }

    /// @notice Returns the expected receiving amount of token out
    function getExpectedReturn(
        address tokenIn,
        address tokenOut,
        uint256 value
    ) external view override returns (uint256) {
        if (value == 0) return 0;

        if (tokenIn == tokenOut) return value;

        SwapRoute[] memory routes = _setRoutes(tokenIn, tokenOut, value);
        return routes[routes.length - 1].expectedReturn;
    }

    /// @notice Performs a swap of token in for token out from given pair
    function _swap(
        address pair,
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        address recipient
    ) internal {
        (address token0, ) = UniswapV2Lib.sortTokens(tokenIn, tokenOut);

        (uint256 amountOut0, uint256 amountOut1) = tokenIn == token0
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));

        IUniswapV2Pair(pair).swap(
            amountOut0,
            amountOut1,
            recipient,
            new bytes(0)
        );
    }

    /// @notice Sets the best swap routes for the entire swaps
    function _setRoutes(
        address tokenIn,
        address tokenOut,
        uint256 value
    ) internal view returns (SwapRoute[] memory routes) {
        address[] memory path = _setPath(tokenIn, tokenOut);
        uint256 length = path.length - 1;
        routes = new SwapRoute[](length);

        for (uint256 i; i < length; ) {
            (address pair, uint256 expectedReturn) = _getExpectedReturn(
                path[i],
                path[i + 1],
                i == 0 ? value : routes[i - 1].expectedReturn
            );

            routes[i] = SwapRoute({
                pair: pair,
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                expectedReturn: expectedReturn
            });

            unchecked {
                i = i + 1;
            }
        }
    }

    /// @notice Computes the address of Uniswap V2 pair contract for
    /// token in and token out with the best return out of all listed
    /// Uniswap V2 factory contracts in the 'factoryList'
    function _getExpectedReturn(
        address tokenIn,
        address tokenOut,
        uint256 value
    ) internal view returns (address pair, uint256 expectedReturn) {
        address[] memory _factoryList = factoryList;
        uint256 length = _factoryList.length;
        uint256 comparison;

        for (uint256 i; i < length; ) {
            address _pair = UniswapV2Lib.pairFor(
                _factoryList[i],
                tokenIn,
                tokenOut
            );

            if (_pair != address(0)) {
                (uint256 reserveIn, uint256 reserveOut) = UniswapV2Lib
                    .getReserves(_pair, tokenIn, tokenOut);

                comparison = UniswapV2Lib.getAmountOut(
                    value,
                    reserveIn,
                    reserveOut
                );
            }

            if (comparison > expectedReturn) {
                pair = _pair;
                expectedReturn = comparison;
            }

            unchecked {
                i = i + 1;
            }
        }
    }

    /// @notice Sets the path between token in and token out
    function _setPath(address tokenIn, address tokenOut)
        internal
        view
        returns (address[] memory path)
    {
        tokenIn = tokenIn.isNative() ? wrappedNative : tokenIn;
        tokenOut = tokenOut.isNative() ? wrappedNative : tokenOut;

        require(tokenIn != tokenOut, "identical addresses");

        if (tokenIn == wrappedNative || tokenOut == wrappedNative) {
            path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;
        } else {
            path = new address[](3);
            path[0] = tokenIn;
            path[1] = wrappedNative;
            path[2] = tokenOut;
        }
    }

    // Uniswap V2 Factory list config

    /// @notice Sets the entire factory list as given values
    function setFactoryList(address[] memory _factoryList)
        external
        onlyGovernance
    {
        factoryList = _factoryList;
    }

    /// @notice Adds the given factory address to the list
    function addFactory(address factory) external onlyGovernance {
        factoryList.push(factory);
    }

    /// @notice Removes the given factory address from the list
    function removeFactory(address factory) external onlyGovernance {
        address[] memory _factoryList = factoryList;
        uint256 length = _factoryList.length;
        uint256 i;

        while (i < length) {
            if (_factoryList[i] == factory) break;

            unchecked {
                i = i + 1;
            }
        }

        factoryList[i] = factoryList[length - 1];
        factoryList.pop();
    }

    /// @notice Returns the entire list of the stored factories
    function getFactoryList() external view returns (address[] memory) {
        return factoryList;
    }

    /// @notice Returns the length of the stored factory list
    function getFactoryLength() external view returns (uint256) {
        return factoryList.length;
    }
}
