// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/Gnosis/IGnosisSafe.sol";
import "src/multisig/GreenwoodModule.sol";
import "test/state/multisig/BaseMultisigFactory.sol";

contract GreenwoodMultisigFactoryTest is BaseMultisigFactory {

    function testClientExecTransaction() public {

        // transaction to transfer 1 WETH to client0 address
        bytes memory transaction = abi.encodeCall(ERC20.transfer, (client0, 1 ether));

        // assert initial state is as expected
        assertEq(weth.balanceOf(address(safe)), 100 ether);
        assertEq(weth.balanceOf(address(client0)), 0);

        // set msg.sender to client0 for the next call
        vm.prank(client0);

        // execute transaction with all owner signatures present
        module.execTransaction(
            address(weth), 
            0, 
            transaction, 
            Enum.Operation.Call
        );

        // assert that transaction executed successfully
        assertEq(weth.balanceOf(address(safe)), 99 ether);
        assertEq(weth.balanceOf(address(client0)), 1 ether);
    }

    function testClientExecTransactionRestrictedSignatureRevert() public {

        // transaction to swap the client1 owner for newOwner
        bytes memory transaction = abi.encodeCall(OwnerManager.swapOwner, (address(0x1), client0, newOwner));

        // assert initial state is as expected
        assertEq(safe.isOwner(client0), true);
        assertEq(safe.isOwner(newOwner), false);

        // set msg.sender to client0 for the next call
        vm.prank(client0);

        // expect that the next call will revert because a call to a restricted selector is made
        vm.expectRevert(bytes("GW001"));
 
        // execute transaction with all owner signatures present
        module.execTransaction(
            address(safe), 
            0, 
            transaction, 
            Enum.Operation.Call
        );
    }

    function testManagerExecTransactionRevert() public {

        // transaction to transfer 1 WETH to manager address
        bytes memory transaction = abi.encodeCall(ERC20.transfer, (manager, 1 ether));

        // assert initial state is as expected
        assertEq(weth.balanceOf(address(safe)), 100 ether);
        assertEq(weth.balanceOf(address(manager)), 0);

        // set msg.sender to client0 for the next call
        vm.prank(manager);

        // expect that the next call will revert because the manager is not a client
        vm.expectRevert();

        // execute transaction with all owner signatures present
        module.execTransaction(
            address(weth), 
            0, 
            transaction, 
            Enum.Operation.Call
        );
    }

    function testSwapOwner() public {

        // assert initial state is as expected
        assertEq(safe.isOwner(client0), true);
        assertEq(safe.isOwner(newOwner), false);
        assertEq(module.client(), client0);
        assertEq(module.hasRole(module.CLIENT_ROLE(), client0), true);
        assertEq(module.hasRole(module.CLIENT_ROLE(), newOwner), false);

        // set msg.sender to client0 for the next call
        vm.prank(client0);

        // swap client1 with newOwner
        module.swapOwner(newOwner);

        // assert that transaction executed successfully
        assertEq(safe.isOwner(client0), false);
        assertEq(safe.isOwner(newOwner), true);
        assertEq(module.client(), newOwner);
        assertEq(module.hasRole(module.CLIENT_ROLE(), client0), false);
        assertEq(module.hasRole(module.CLIENT_ROLE(), newOwner), true);
    }

    function testManagerSwapOwnerRevert() public {

        // assert initial state is as expected
        assertEq(safe.isOwner(client0), true);
        assertEq(safe.isOwner(newOwner), false);
        assertEq(module.client(), client0);
        assertEq(module.hasRole(module.CLIENT_ROLE(), client0), true);
        assertEq(module.hasRole(module.CLIENT_ROLE(), newOwner), false);

        // set msg.sender to client0 for the next call
        vm.prank(manager);

        // expect that the next call will revert because the manager is not a client
        vm.expectRevert();

        // swap client1 with newOwner
        module.swapOwner(newOwner);
    }
}