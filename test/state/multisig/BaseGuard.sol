// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "safe-contracts/base/GuardManager.sol";
import "safe-contracts/common/StorageAccessible.sol";

import "src/multisig/GreenwoodGuard.sol";
import "test/state/multisig/BaseGnosisSafe.sol";

contract BaseGuard is BaseGnosisSafe {
    GreenwoodGuard public guard;

    function labelAddresses() public virtual override {
        super.labelAddresses();

        vm.label(address(guard), "greenwoodGuard");
    }

    function setUp() public virtual override {
        super.setUp();

        // Greenwood guard instance
        guard = new GreenwoodGuard();

        // transaction to add greenwood guard contract to gnosis safe vault
        bytes memory transaction = abi.encodeCall(GuardManager.setGuard, address(guard));

        // create safe encoded transaction data that will be signed by all owners
        bytes memory transactionData = safe.encodeTransactionData(
            address(safe), 
            0, 
            transaction, 
            Enum.Operation.Call, 
            0, 
            0, 
            0, 
            address(0), 
            payable(0), 
            safe.nonce()
        );
        
        // roll signatures into a gnosis-compliant format
        bytes memory gnosisSignatures = GnosisUtils.buildGnosisSignatures(
            abi.encode(privKeyClient1, privKeyManager, privKeyClient0), 
            keccak256(transactionData),
            3
        );

        // make sure that the signatures are valid
        safe.checkSignatures(keccak256(transactionData), transactionData, gnosisSignatures);

        // assert initial state is as expected
        assertEq(safe.nonce(), 0);

        // execute transaction with all owner signatures present
        safe.execTransaction(
            address(safe), 
            0, 
            transaction, 
            Enum.Operation.Call, 
            0, 
            0, 
            0, 
            address(0), 
            payable(0), 
            gnosisSignatures
        );

        // assert that transaction executed successfully
        assertEq(safe.nonce(), 1);

        // label addresses
        labelAddresses();
    }
}