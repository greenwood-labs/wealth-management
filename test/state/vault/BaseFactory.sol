// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/vault/BeakerFactory.sol";
import "src/vault/BeakerPeriodicVault.sol";
import "src/vault/strategies/template/PeriodicStrategy.sol";

contract BaseFactory is Test {
    BeakerFactory public factory;
    BeakerPeriodicVault public vaultTemplate;

    bytes32 public constant VAULT_IMPL_ID = keccak256("BeakerPeriodicVaultV1");

    // private keys
    uint256 public privKeyGovernance = 1;

    // owners
    address public governance = vm.addr(privKeyGovernance);

    function labelAddresses() public virtual {
        vm.label(address(factory), "beakerFactory");
        vm.label(address(vaultTemplate), "vaultTemplate");
    }

    function setUp() public virtual {

        // beaker factory instance
        factory = new BeakerFactory(governance);

        // vault template instance
        vaultTemplate = new BeakerPeriodicVault(governance);

        // set vault implementation to the factory
        factory.setImplementation(VAULT_IMPL_ID, address(vaultTemplate));

        // label addresses
        labelAddresses();
    }

}