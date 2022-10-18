// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/multisig/GreenwoodMultisigFactory.sol";
import "test/state/multisig/BaseModuleProxyFactory.sol";

contract BaseMultisigFactory is BaseModuleProxyFactory {
    GreenwoodMultisigFactory public multisigFactory;
    GreenwoodModule public module;

    function labelAddresses() public virtual override {
        super.labelAddresses();

        vm.label(address(multisigFactory), "GreenwoodMultisigFactory");
        vm.label(address(module), "GreenwoodModule");
    }

    function setUp() public virtual override {
        super.setUp();

        // create Greenwood multisig factory instance
        multisigFactory = new GreenwoodMultisigFactory(
            address(guard),
            address(moduleFactory), 
            address(safeFactory),
            GNOSIS_SAFE_FALLBACK_HANDLER,
            GNOSIS_SAFE_SINGLETON
        );

        assertEq(multisigFactory.guard(), address(guard));
        assertEq(multisigFactory.moduleProxyFactory(), address(moduleFactory));
        assertEq(multisigFactory.safeFactory(), address(safeFactory));
        assertEq(multisigFactory.owner(), address(this));
        assertEq(multisigFactory.nonce(), 0);

        (address _safe, address _module) = multisigFactory.deployGreenwoodMultisig(
            client0,
            address(moduleTemplate)
        );

        // override the base safe
        safe = GnosisSafe(payable(_safe));
        module = GreenwoodModule(_module);

        // deal some WETH to the greenwood multisig
        deal(WETH, address(safe), 100 ether);

        // check that the greenwood multisig has been properly initialized
        assertEq(multisigFactory.nonce(), 1);
        assertEq(safe.isModuleEnabled(address(_module)), true);
        assertEq(module.hasRole(module.CLIENT_ROLE(), client0), true);
        assertEq(module.safe(), address(_safe));
        assertEq(module.guard(), address(guard));
        assertEq(weth.balanceOf(address(safe)), 100 ether);

        // label addresses
        labelAddresses();
    }
}