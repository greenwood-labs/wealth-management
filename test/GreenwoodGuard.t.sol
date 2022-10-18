// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "test/state/multisig/BaseGuard.sol";

contract GreenwoodGuardTest is BaseGuard {

    function testCheckTransactionAddOwnerWIthThresholdRevert() public {

        // transaction to add a new owner and update the multisig threshold to 3/4
        bytes memory transaction = abi.encodeCall(OwnerManager.addOwnerWithThreshold, (newOwner, 3));

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
        assertEq(safe.getThreshold(), 2);
        assertEq(safe.isOwner(newOwner), false);
        assertEq(safe.getOwners().length, 3);

        // expect that the next call will revert because a call to a restricted selector is made
        vm.expectRevert(bytes("GW001"));

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
    }

    function testCheckTransactionRemoveOwnerRevert() public {

        // transaction to remove the client1 owner and change the threshold to 1/2
        bytes memory transaction = abi.encodeCall(OwnerManager.removeOwner, (client0, client1, 1));

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
        assertEq(safe.getThreshold(), 2);
        assertEq(safe.isOwner(client1), true);
        assertEq(safe.getOwners().length, 3);

        // expect that the next call will revert because a call to a restricted selector is made
        vm.expectRevert(bytes("GW001"));

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
    }

    function testCheckTransactionSwapOwnerRevert() public {

        // transaction to swap the client1 owner for newOwner
        bytes memory transaction = abi.encodeCall(OwnerManager.swapOwner, (client0, client1, newOwner));

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
        assertEq(safe.isOwner(client1), true);
        assertEq(safe.isOwner(newOwner), false);

        // expect that the next call will revert because a call to a restricted selector is made
        vm.expectRevert(bytes("GW001"));

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
    }

    function testCheckTransactionChangeThresholdRevert() public {

        // transaction to change the threshold from 2/3 to 3/3
        bytes memory transaction = abi.encodeCall(OwnerManager.changeThreshold, 3);

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
        assertEq(safe.getThreshold(), 2);

        // expect that the next call will revert because a call to a restricted selector is made
        vm.expectRevert(bytes("GW001"));

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
    }

    function testCheckTransactionSetGuardRevert() public {

        // deploy a new guard contract
        GreenwoodGuard newGuard = new GreenwoodGuard();

        // transaction to set the guard to a new contract address
        bytes memory transaction = abi.encodeCall(GuardManager.setGuard, address(newGuard));

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

        // expect that the next call will revert because a call to a restricted selector is made
        vm.expectRevert(bytes("GW001"));

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
    }
}
