// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "test/state/multisig/BaseMultisigFactory.sol";
import "test/state/vault/BaseOpynStrategy.sol";

contract BaseIntegration is BaseMultisigFactory, BaseOpynStrategy {

    function labelAddresses() public virtual override(BaseMultisigFactory, BaseOpynStrategy) {
        super.labelAddresses();
    }

    function setUp() public virtual override(BaseMultisigFactory, BaseOpynStrategy) {
        super.setUp();

        labelAddresses();
    }
}