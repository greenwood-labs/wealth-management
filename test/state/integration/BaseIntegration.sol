// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "test/state/multisig/BaseMultisigFactory.sol";
import "test/state/vault/BaseMockPricer.sol";

contract BaseIntegration is BaseMultisigFactory, BaseMockPricer {

    function labelAddresses() public virtual override(BaseMultisigFactory, BaseMockPricer) {
        super.labelAddresses();
    }

    function setUp() public virtual override(BaseMultisigFactory, BaseMockPricer) {
        super.setUp();

        labelAddresses();
    }
}