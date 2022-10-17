// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/IBaseStrategy.sol";

interface IReinvestStrategy is IBaseStrategy {
    struct Reward {
        address token;
        uint256 value;
    }

    function accruedRewards() external view returns (Reward[] memory);

    function totalRewards() external view returns (uint256);

    function totalDeposits() external view returns (uint256);

    function totalValues() external view returns (uint256);

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function reinvest() external;

    event Reinvest(address indexed caller, uint256 indexed value);

    event Migrate(
        address indexed oldStrategy,
        address indexed newStrategy,
        uint256 indexed value
    );
}