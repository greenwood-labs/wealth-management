// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "test/state/integration/BaseIntegration.sol";

contract IntegrationTest is BaseIntegration {

    function testIntegration() public {

        console.log(address(strategy));
        console.log(address(vault));
        console.log(address(module));
        console.log(address(safe));

       assertTrue(true);
    }
}