// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "src/multisig/GreenwoodGuard.sol";
import "src/multisig/GreenwoodModule.sol";
import "src/multisig/GreenwoodMultisigFactory.sol";
import "src/multisig/ModuleProxyFactory.sol";

/// @title Deploy Multisig - Deploys the Greenwood Multisig architecture
contract DeployMultisig is Script {

    GreenwoodGuard public guard;
    GreenwoodModule public moduleTemplate;
    GreenwoodMultisigFactory public multisigFactory;
    ModuleProxyFactory public moduleFactory;

    // Gnosis Safe constant addresses
    address public constant GNOSIS_SAFE_PROXY_FACTORY = 0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2;
    address public constant GNOSIS_SAFE_SINGLETON = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;
    address public constant GNOSIS_SAFE_FALLBACK_HANDLER = 0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy the module template instance
        moduleTemplate = new GreenwoodModule();

        // Greenwood guard instance
        guard = new GreenwoodGuard();

        // Greenwood module proxy factory instance
        moduleFactory = new ModuleProxyFactory();

        // create Greenwood multisig factory instance
        multisigFactory = new GreenwoodMultisigFactory(
            address(guard),
            address(moduleFactory), 
            GNOSIS_SAFE_PROXY_FACTORY,
            GNOSIS_SAFE_FALLBACK_HANDLER,
            GNOSIS_SAFE_SINGLETON
        );

        vm.stopBroadcast();
    }
}
