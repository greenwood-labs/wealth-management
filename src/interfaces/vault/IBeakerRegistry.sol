// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBeakerRegistry {
    function manager() external view returns (address);

    function getModule(bytes32 id) external view returns (address);

    function getProtocol(uint256 id) external view returns (address);

    event ManagerUpdated(
        address indexed priorManager,
        address indexed newManager
    );

    event ModuleUpdated(bytes32 indexed id, address indexed module);
}
