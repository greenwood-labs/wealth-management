// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "src/interfaces/Uniswap/IUniswapV2.sol";
import "./SafeERC20.sol";

library BeakerNamer {
    string private constant NAME_PREFIX = "Beaker: ";
    string private constant SYMBOL_PREFIX = "BLP: ";

    // token types
    // 0: Uniswap V2 Pair tokens
    // 1: Curve LP tokens

    function setBeakerName(uint8 tokenType, address token)
        internal
        view
        returns (string memory)
    {
        if (tokenType == 0) return setPairName(token);
        else if (tokenType == 1) return setCurveLPSymbol(token);
        else return setTokenName(token);
    }

    function setBeakerSymbol(uint8 tokenType, address token)
        internal
        view
        returns (string memory)
    {
        if (tokenType == 0) return setPairSymbol(token);
        else if (tokenType == 1) return setCurveLPName(token);
        else return setTokenSymbol(token);
    }

    // Beaker: Wrapped AVAX
    function setTokenName(address token) internal view returns (string memory) {
        return string(abi.encodePacked(NAME_PREFIX, SafeERC20.getName(token)));
    }

    // BLP: WAVAX
    function setTokenSymbol(address token)
        internal
        view
        returns (string memory)
    {
        return
            string(abi.encodePacked(NAME_PREFIX, SafeERC20.getSymbol(token)));
    }

    // Beaker: Joe LP Token
    function setPairName(address pair) internal view returns (string memory) {
        return string(abi.encodePacked(NAME_PREFIX, SafeERC20.getName(pair)));
    }

    // BLP: JLP (WAVAX-USDC.e)
    function setPairSymbol(address pair) internal view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    SYMBOL_PREFIX,
                    SafeERC20.getSymbol(pair),
                    "(",
                    SafeERC20.getSymbol(IUniswapV2Pair(pair).token0()),
                    "-",
                    SafeERC20.getSymbol(IUniswapV2Pair(pair).token1()),
                    ")"
                )
            );
    }

    // Beaker: Curve av3CRV
    function setCurveLPName(address token)
        internal
        view
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    NAME_PREFIX,
                    "Curve ",
                    SafeERC20.getSymbol(token)
                )
            );
    }

    // BLP: av3CRV
    function setCurveLPSymbol(address token)
        internal
        view
        returns (string memory)
    {
        return
            string(abi.encodePacked(SYMBOL_PREFIX, SafeERC20.getSymbol(token)));
    }
}
