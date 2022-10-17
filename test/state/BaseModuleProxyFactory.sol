// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/multisig/GreenwoodModule.sol";
import "src/multisig/ModuleProxyFactory.sol";
import "test/state/BaseGuard.sol";

contract BaseModuleProxyFactory is BaseGuard {
    ModuleProxyFactory public moduleFactory;
    GreenwoodModule public moduleTemplate;

    function labelAddresses() public virtual override {
        super.labelAddresses();

        vm.label(address(moduleFactory), "ModuleProxyFactory");
        vm.label(address(moduleTemplate), "ModuleTemplate");
    }

    function setUp() public virtual override {
        super.setUp();

        // Deploy the module template instance
        moduleTemplate = new GreenwoodModule();

        // Greenwood module proxy factory instance
        moduleFactory = new ModuleProxyFactory();

        // label addresses
        labelAddresses();
    }
}