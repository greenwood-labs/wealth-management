// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "test/state/multisig/BaseGnosisSafe.sol";

import "safe-contracts/base/OwnerManager.sol";

contract GnosisExecutionTest is BaseGnosisSafe {

    function testSafeExecTransaction() public {

        // transaction to transfer 1 WETH to client0 address
        bytes memory transaction = abi.encodeCall(ERC20.transfer, (client0, 1 ether));

        // create safe encoded transaction data that will be signed by all owners
        bytes memory transactionData = safe.encodeTransactionData(
            address(weth), 
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
        assertEq(weth.balanceOf(address(safe)), 100 ether);
        assertEq(weth.balanceOf(address(client0)), 0);

        // execute transaction with all owner signatures present
        safe.execTransaction(
            address(weth), 
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
        assertEq(weth.balanceOf(address(safe)), 99 ether);
        assertEq(weth.balanceOf(address(client0)), 1 ether);
    }

    function testAddOwnerWIthThreshold() public {

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
        assertEq(safe.getThreshold(), 3);
        assertEq(safe.isOwner(newOwner), true);
        assertEq(safe.getOwners().length, 4);
    }

    function testRemoveOwner() public {

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
        assertEq(safe.getThreshold(), 1);
        assertEq(safe.isOwner(client1), false);
        assertEq(safe.getOwners().length, 2);
    }

    function testSwapOwner() public {

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
        assertEq(safe.isOwner(client1), false);
        assertEq(safe.isOwner(newOwner), true);
    }

    function testChangeThreshold() public {

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
        assertEq(safe.getThreshold(), 3);
    }
}
