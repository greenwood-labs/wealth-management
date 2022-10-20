// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "test/state/multisig/BaseMultisigFactory.sol";
import "test/state/vault/BaseMockPricer.sol";

contract BaseIntegration is BaseMultisigFactory, BaseMockPricer {

    function labelAddresses() public virtual override(BaseMultisigFactory, BaseMockPricer) {
        super.labelAddresses();
    }

    function setUpLogs() public view {
        console.log("");
        console.log("This integration test demonstrates how a wealth manager can use the Greenwood protocol to recommend");
        console.log("multi-step DeFi transactions to their clients without taking custody of client assets and whithout the client");
        console.log("having to execute each step manually.");
        console.log("");
        console.log("##############################################");
        console.log("###        GREENWOOD MULTISIG SETUP        ###");
        console.log("##############################################");
        console.log("");
        console.log("Greenwood core team deploys contracts necesary to create Greenwood Multisigs");
        console.log("");
        console.log("Greenwood Guard Address:       %s", address(guard));
        console.log("Module Proxy Factory Address:  %s", address(moduleFactory));
        console.log("Multisig Factory Address:      %s", address(multisigFactory));

        console.log("");
        console.log("##############################################");
        console.log("###         GREENWOOD VAULT SETUP          ###");
        console.log("##############################################");
        console.log("");
        console.log("A Greenwood vault implementing a multi-step investment strategy is deployed by the Greenwood core team");
        console.log("");
        console.log("Vault Factory Address:                 %s", address(vaultFactory));
        console.log("Greenwood Vault Address:               %s", address(strategy));
        console.log("Opyn Buffered Note Strategy Address:   %s", address(vault));

        console.log("");
        console.log("##############################################");
        console.log("###     INTEGRATION TEST INITIAL STATE     ###");
        console.log("##############################################");
        console.log("");    
        console.log("The RIA creates a Greenwood multisig and makes their client the owner of the multisig");
        console.log("");
        console.log("Gnosis Safe Address:        %s", address(safe));
        console.log("Greenwood Module Address:   %s", address(module));
        console.log("Client Address:             %s", address(client0));
        console.log("Counterparty Address:       %s", address(counterparty));
        console.log("Gnosis Safe WETH balance:   %s WETH", weth.balanceOf(address(safe)) / 1e18);
    }

    function setUp() public virtual override(BaseMultisigFactory, BaseMockPricer) {
        super.setUp();

        setUpLogs();
    
        labelAddresses();
    }
}