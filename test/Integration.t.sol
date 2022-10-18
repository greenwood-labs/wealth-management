// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "test/state/multisig/BaseMultisigFactory.sol";
import "test/state/vault/BaseVaultFactory.sol";

contract IntegrationTest is BaseMultisigFactory, BaseVaultFactory {

    function labelAddresses() public virtual override(BaseMultisigFactory, BaseVaultFactory) {
        super.labelAddresses();
    }

    function setUp() public virtual override(BaseMultisigFactory, BaseVaultFactory) {
        super.setUp();
    }


    function testIntegration() public {

       assertTrue(true);
    }
}