// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "src/interfaces/Gamma/IOracle.sol";

contract MockPricer {
    IOracle public oracle;

    uint256 internal price;
    address public asset;

    constructor(address _asset, address _oracle) {
        asset = _asset;
        oracle = IOracle(_oracle);
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function getPrice() external view returns (uint256) {
        return price;
    }

    function setExpiryPriceInOracle(uint256 _expiryTimestamp, uint256 _price) external {
        oracle.setExpiryPrice(asset, _expiryTimestamp, _price);
    }

    function getHistoricalPrice(uint80  /* _roundId */) external view returns (uint256, uint256) {
        return (price, block.timestamp);
    }
}