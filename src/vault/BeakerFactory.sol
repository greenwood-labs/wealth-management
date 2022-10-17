// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/IBeakerFactory.sol";
import "src/libraries/BytesLib.sol";

import "src/vault/base/Deployer.sol";
import "src/vault/base/Governed.sol";
import "src/vault/base/Initializable.sol";

contract BeakerFactory is IBeakerFactory, Deployer, Governed, Initializable {
    using BytesLib for bytes;

    /// @notice mapping to retrieve a vault contract using its ID
    mapping(uint256 => address) public override getVault;

    /// @notice mapping to retrieve a strategy contract using its ID
    mapping(uint256 => address) public override getStrategy;

    /// @notice the ID of this factory
    uint256 public override protocolId;

    /// @notice the number of deployed vaults
    uint256 public override numVaults;

    /// @notice the number of deployed strategies
    uint256 public override numStrategies;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _governance) Governed(_governance) {}

    /// @notice Initializes the beaker factory
    /// @param params parameters to initialize the factory
    function initialize(bytes memory params)
        external
        override
        initializer
        returns (bool)
    {
        protocolId = params.toUint256(0);

        return true;
    }

    /// @notice Deploys both vault and strategy
    /// @param vaultId logic contract version of the vault
    /// @param strategyId logic contract version of the strategy
    /// @param vaultParams parameters to initialize the vault
    /// @param strategyParams parameters to initialize the strategy
    // both vault and strategy contracts need each other's address on its initialization
    // therefore we compute the address of the strategy contract beforehand with using its salt
    // when both contracts are being deployed at the same time
    function deploy(
        bytes32 vaultId,
        bytes32 strategyId,
        bytes memory vaultParams,
        bytes memory strategyParams
    ) external onlyGovernance {
        // set IDs of vault and strategy
        uint256 _vaultId = numVaults;
        uint256 _stategyId = numStrategies;

        // unique salt for both vault and strategy gets generated with
        // the version of logic contract and its own ID

        // compute the address of strategy to be deployed
        address _strategy = _computeAddress(
            strategyId,
            _getSalt(strategyId, _stategyId)
        );

        // deploy the vault contract
        address vault = _deploy(
            vaultId,
            _getSalt(vaultId, _vaultId),
            abi.encodePacked(_strategy).concat(vaultParams)
        );

        // deploy the strategy contract
        address strategy = _deploy(
            strategyId,
            _getSalt(strategyId, _stategyId),
            abi.encodePacked(vault).concat(strategyParams)
        );

        // store the mappings
        getVault[_vaultId] = vault;
        getStrategy[_stategyId] = strategy;

        // increment both IDs by 1
        unchecked {
            numVaults = _vaultId + 1;
            numStrategies = _stategyId + 1;
        }
    }

    /// @notice Deploys a new vault
    /// @param vaultId logic contract version of the vault
    /// @param params parameters to initialize the vault
    // the address of the strategy must be included in the parameters since only the vault is being deployed
    function deployVault(bytes32 vaultId, bytes memory params)
        external
        onlyGovernance
    {
        uint256 id = numVaults;

        address vault = _deploy(vaultId, _getSalt(vaultId, id), params);

        getVault[id] = vault;

        unchecked {
            numVaults = id + 1;
        }
    }

    /// @notice Deploys a new strategy
    /// @param strategyId logic contract version of the vault
    /// @param params parameters to initialize the vault
    // the address of the vault must be included in the parameters since only the strategy is being deployed
    function deployStrategy(bytes32 strategyId, bytes memory params)
        external
        onlyGovernance
    {
        uint256 id = numStrategies;

        address strategy = _deploy(
            strategyId,
            _getSalt(strategyId, id),
            params
        );

        getStrategy[id] = strategy;

        unchecked {
            numStrategies = id + 1;
        }
    }

    /// @notice Sets a mapping for the given version ID and logic contract address
    function setImplementation(bytes32 id, address implementation) external {
        _implementations[id] = implementation;
    }
}
