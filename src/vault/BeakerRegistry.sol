// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/IBeakerManager.sol";
import "src/interfaces/vault/IBeakerRegistry.sol";
import "src/vault/base/Governed.sol";

contract BeakerRegistry is IBeakerRegistry, Governed {
    // mapping to retrieve a module contract using its ID
    mapping(bytes32 => address) internal _modules;

    // interface of the beaker manager contract
    IBeakerManager private _manager;

    /// @notice address of the beaker router contract
    address public router;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _governance) Governed(_governance) {}

    /// @notice Sets a new beaker manager contract
    /// @param newManager the new manager to set
    function setManager(address newManager) external onlyGovernance {
        emit ManagerUpdated(address(_manager), newManager);

        _manager = IBeakerManager(newManager);
    }

    /// @notice Sets a mapping for the given module contract
    /// @param id the version ID of module to set
    /// @param module the address of module to set
    function setModule(bytes32 id, address module) external onlyGovernance {
        _modules[id] = module;

        emit ModuleUpdated(id, module);
    }

    /// @notice Sets a new beaker router contract
    /// @param _router the new router to set
    function setRouter(address _router) external onlyGovernance {
        router = _router;
    }

    /// @notice Returns the address of the module contract for the given ID
    function getModule(bytes32 id) external view override returns (address) {
        return _modules[id];
    }

    /// @notice Returns the address of the factory contract for the given ID
    function getProtocol(uint256 id) external view override returns (address) {
        return _manager.getProtocol(id);
    }

    /// @notice Returns the address of the beaker manager contract
    function manager() external view override returns (address) {
        return address(_manager);
    }
}
