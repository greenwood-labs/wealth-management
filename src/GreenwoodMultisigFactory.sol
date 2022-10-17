// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "safe-contracts/proxies/GnosisSafeProxyFactory.sol";

import "src/interfaces/IGnosisSafe.sol";
import "src/GreenwoodModule.sol";
import "src/ModuleProxyFactory.sol";

/// @title Greenwood Multisig Factory - A factory contract to deploy greenwood multisig instances
contract GreenwoodMultisigFactory {

    struct StorageSlot {
        address guard;
        address moduleProxyFactory;
        address safeFactory;
        address gnosisFallbackHandler;
        address gnosisSingleton;
        address owner;
        uint256 nonce;
    }

    event multisigDeployment(address safe, address module, address moduleTemplate, address client, uint256 nonce);

    // storage slot for the factory
    // This enables safe delegate calls to the factory
    bytes32 public constant STORAGE_SLOT = keccak256("Greenwood.MultisigFactory.storage.slot");
    
    /// @param _guard The Gnosis Safe guard address
    /// @param _moduleProxyFactory The Greenwood module proxy factory address
    /// @param _safeFactory The Gnosis Safe factory address
    /// @param _gnosisFallbackHandler The Gnosis Safe fallback handler address
    /// @param _gnosisSingleton The Gnosis Safe singleton address
    constructor(
        address _guard,
        address _moduleProxyFactory,
        address _safeFactory,
        address _gnosisFallbackHandler,
        address _gnosisSingleton
    ) {
        StorageSlot storage slot = _getStorageSlot();

        slot.guard = _guard;
        slot.moduleProxyFactory = _moduleProxyFactory;
        slot.safeFactory = _safeFactory;
        slot.gnosisFallbackHandler = _gnosisFallbackHandler;
        slot.gnosisSingleton = _gnosisSingleton;
        slot.owner = msg.sender;
        slot.nonce = 0;
    }

    /// @dev Deploys a new Grennwood multisig instance (Gnosis safe proxy and linked module proxy contracts)
    /// @param client The client account
    /// @param moduleTemplate The Greenwood module template contract to deploy a proxy from
    function deployGreenwoodMultisig(
        address client,
        address moduleTemplate
    ) external returns (address safe, address module) {

        // get storage data
        StorageSlot storage slot = _getStorageSlot();

        // unique salt nonce to use for deployment of the module
        uint256 saltNonce = slot.nonce;
        
        // create Greenwood module proxy instance, and call setup() upon deployment
        module = ModuleProxyFactory(slot.moduleProxyFactory).deployModule(
            moduleTemplate, 
            bytes(""), 
            saltNonce 
        );

        // add owner to array
        address[] memory owners = new address[](1);
        owners[0] = client;
    
        // Delegate call from the safe so that the multisig can be initialized right after it is deployed
        bytes memory data = abi.encodeCall(GreenwoodMultisigFactory.initializeGreenwoodMultisig, module);

        // create gnosis initializer payload
        bytes memory initializerPayload = abi.encodeCall(
            IGnosisSafe.setup, 
            (
                owners,                     // owners
                1,                          // threshold
                address(this),              // to
                data,                       // data
                slot.gnosisFallbackHandler, // fallback manager
                address(0),                 // payment token
                0,                          // payment amount
                payable(address(0))         // payment receiver
            )
        );

        // deploy a safe proxy using initializer values for the GnosisSafe.setup() call
        safe = payable(address(GnosisSafeProxyFactory(slot.safeFactory).createProxyWithNonce(
            slot.gnosisSingleton, 
            initializerPayload, 
            saltNonce
        )));

        // finally, we can call setup() on the module to initialize it
        GreenwoodModule(module).setup(client, safe, slot.guard);

        // increment nonce
        slot.nonce++;

        // emit event
        emit multisigDeployment(safe, module, moduleTemplate, client, saltNonce);
    }

    /// @dev Initializes a Greenwood multisig instance via delegate call to this contract.
    ///      This function can only be called by the safe proxy via a delegate call, otherwise it will fail.
    ///      This pattern was chosen over performing a delegate call to a multicall contract
    ///      since the safe address cannot be computed via create2 because the initializer payload
    ///      is used to generate the salt nonce for the Gnosis Safe proxy, which itself would need to 
    ///      contain the safe address to be able to initialize the module.
    /// @param module The module proxy address to enable for the safe
    function initializeGreenwoodMultisig(address module) external {

        // enable module
        IGnosisSafe(address(this)).enableModule(module);

        // activate guard
        IGnosisSafe(address(this)).setGuard(_getStorageSlot().guard);
    }

    function _getStorageSlot() internal pure returns (StorageSlot storage s) {

        bytes32 slot = STORAGE_SLOT;

        assembly {
            s.slot := slot
        }
    }

    function guard() external view returns (address) {
        return _getStorageSlot().guard;
    }

    function moduleProxyFactory() external view returns (address) {
        return _getStorageSlot().moduleProxyFactory;
    }

    function safeFactory() external view returns (address) {
        return _getStorageSlot().safeFactory;
    }

    function owner() external view returns (address) {
        return _getStorageSlot().owner;
    }

    function nonce() external view returns (uint256) {
        return _getStorageSlot().nonce;
    }
}