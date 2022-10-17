// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/IBeakerManager.sol";
import "src/interfaces/vault/IBeakerRegistry.sol";
import "src/libraries/BytesLib.sol";
import "src/vault/base/Deployer.sol";
import "src/vault/base/Governed.sol";

contract BeakerManager is IBeakerManager, Deployer, Governed {
    using BytesLib for bytes;

    /// @notice mapping to retrieve a factory contract using its ID
    mapping(uint256 => address) public override getProtocol;

    /// @notice the number of deployed factories
    uint256 public override numProtocols;

    /// @notice address of the beaker registry contract
    address public override registry;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _governance) Governed(_governance) {}

    /// @notice Deploys a new factory
    /// @param factoryId logic contract version of the factory
    function deploy(bytes32 factoryId) external onlyGovernance {
        uint256 protocolId = numProtocols;

        address factory = _deploy(
            factoryId,
            _getSalt(factoryId, protocolId),
            abi.encodePacked(protocolId)
        );

        getProtocol[protocolId] = factory;

        unchecked {
            numProtocols = protocolId + 1;
        }
    }

    /// @notice Sets a mapping for the given version ID and logic contract address
    function setImplementation(bytes32 id, address implementation)
        external
        onlyGovernance
    {
        _implementations[id] = implementation;
    }

    /// @notice Sets a new beaker registry contract
    /// @param newRegistry the new registry to set
    function setRegistry(address newRegistry) external onlyGovernance {
        registry = newRegistry;
    }
}
