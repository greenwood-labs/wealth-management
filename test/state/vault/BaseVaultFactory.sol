// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "test/state/base/BaseFundedAccount.sol";

import "src/vault/BeakerFactory.sol";
import "src/vault/BeakerPeriodicVault.sol";

contract BaseVaultFactory is BaseFundedAccount {
    BeakerFactory public vaultFactory;
    BeakerPeriodicVault public vaultTemplate;

    bytes32 public constant VAULT_IMPL_ID = keccak256("BeakerPeriodicVaultV1");

    // private keys
    uint256 public privKeyGovernance = 1847329;

    // owners
    address public governance = vm.addr(privKeyGovernance);

    function labelAddresses() public virtual override {
        super.labelAddresses();

        vm.label(address(vaultFactory), "beakerFactory");
        vm.label(address(vaultTemplate), "vaultTemplate");
    }

    function setUp() public virtual override {
        super.setUp();

        // beaker factory instance
        vaultFactory = new BeakerFactory(governance);

        // vault template instance
        vaultTemplate = new BeakerPeriodicVault(governance);

        // set vault implementation to the factory
        vaultFactory.setImplementation(VAULT_IMPL_ID, address(vaultTemplate));

        // label addresses
        labelAddresses();
    }

}