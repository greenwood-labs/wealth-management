// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/access/AccessControl.sol";

import "src/interfaces/IGnosisSafe.sol";
import "src/interfaces/IGuard.sol";

/// @title Greenwood Module - A module contract to grant the client superuser access to the multisig
contract GreenwoodModule is AccessControl {

    // client account
    address public client;

    // gnosis contract addresses
    address public safe;
    address public guard;

    // client role
    bytes32 public constant CLIENT_ROLE = keccak256("CLIENT_ROLE");

    constructor() {
       // By setting the safe to 0x1, the setup function can no longer be called.
       // This disallows any clients from registering for this module which disables
       // all functionality. This is because the deployed template contract
       // should not be usable on its own, but only through proxy contracts.
       safe = address(0x1);
    }

    /// @dev Initializes the contract and grants privileges to the client
    /// @param _client The client account
    /// @param _safe The Gnosis Safe address
    /// @param _guard The Gnosis Safe guard address
    function setup(
        address _client,
        address _safe, 
        address _guard
    ) external {

        // Safe can only be 0x at initialization.
        // Ensures setup is called only once.
        require(safe == address(0), "GW005");

        // Grant the client role to the account
        _grantRole(CLIENT_ROLE, _client);

        // Enable the accounts as clients
        client = _client;

        safe = _safe;
        guard = _guard;
    }

    /// @dev Allows the client to execute transactions on the multisig without needing a threshold of signatures
    /// @param to The address to send the transaction to
    /// @param value The amount of ETH to send
    /// @param data The transaction data to send
    /// @param operation The transaction operation type (either call or delegatecall)
    /// @return success The success status of the transaction
    function execTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) external onlyRole(CLIENT_ROLE) returns (bool success) {
        
        // check transaction using guard
        if (guard != address(0)) {
            IGuard(guard).checkTransaction(
                to,
                value,
                data,
                operation,
                0,
                0,
                0,
                address(0),
                payable(0),
                bytes(""),
                msg.sender
            );
        }

        // execute the transaction on the gnosis safe
        success = IGnosisSafe(safe).execTransactionFromModule(
            to,
            value,
            data,
            operation
        );

        return success;
    }

    /// @dev Allows the client to swap out the privileged owner of the multisig to a new address
    /// @param newOwner The new owner address that will assume the role of the privileged owner
    /// @return success The success status of the transaction
    function swapOwner(address newOwner) external onlyRole(CLIENT_ROLE) returns (bool success) {

        // retreive the gnosis prev owner. This is used for updating
        // the linked list of owners on the safe contract. When the multisig only
        // contains 1 owner, the prev owner is the sentinel address
        address prevOwner = address(0x1);

        // revoke client access to the old account and grant client access to the new account
        _revokeRole(CLIENT_ROLE, msg.sender);
        _grantRole(CLIENT_ROLE, newOwner);

        // update the client account
        client = newOwner;
        
        // update owner on gnosis safe vault
        success = IGnosisSafe(safe).execTransactionFromModule(
            address(safe),
            0,
            abi.encodeCall(IGnosisSafe.swapOwner, (prevOwner, msg.sender, newOwner)),
            Enum.Operation.Call
        );
        
        return success;
    }
}