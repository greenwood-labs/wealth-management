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
        console.log("##############################################");
        console.log("###        GREENWOOD MULTISIG SETUP        ###");
        console.log("##############################################");
        console.log("");
        console.log("Gnosis Safe Address:           ", address(safe));
        console.log("Greenwood Module Address:      ", address(module));
        console.log("Greenwood Guard Address:       ", address(guard));
        console.log("Module Proxy Factory Address:  ", address(moduleFactory));
        console.log("Multisig Factory Address:      ", address(multisigFactory));

        console.log("");
        console.log("##############################################");
        console.log("###         GREENWOOD VAULT SETUP          ###");
        console.log("##############################################");
        console.log("");
        console.log("Vault Factory Address:                 ", address(vaultFactory));
        console.log("Greenwood Vault Address:               ", address(strategy));
        console.log("Opyn Buffered Note Strategy Address:   ", address(vault));

        console.log("");
        console.log("##############################################");
        console.log("###     INTEGRATION TEST INITIAL STATE     ###");
        console.log("##############################################");
        console.log("");
        console.log("Client Address:             ", address(client0));
        console.log("Counterparty Address:       ", address(counterparty));
        console.log("Gnosis Safe WETH balance:   ", weth.balanceOf(address(safe)) / 1e18, "WETH");
    }

    function setUp() public virtual override(BaseMultisigFactory, BaseMockPricer) {
        super.setUp();

        setUpLogs();
    
        labelAddresses();
    }
}