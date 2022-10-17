// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/utils/introspection/IERC165.sol";
import "safe-contracts/common/Enum.sol";
import "safe-contracts/base/GuardManager.sol";
import "safe-contracts/base/OwnerManager.sol";

/// @title Greenwood Guard - A guard contract to prevent calls to restricted function selectors on the Gnosis Safe
contract GreenwoodGuard is IERC165, Guard {

    // restricted function selectors that cannot be called by the safe
    mapping (bytes4 => bool) internal restrictedSelectors;

    constructor() {
        // add restrictions to function selectors that could alter the invariant that
        // greenwood gnosis safe multisig contracts always have a threshold of 2 with 3 owners
        restrictedSelectors[OwnerManager.addOwnerWithThreshold.selector] = true;
        restrictedSelectors[OwnerManager.removeOwner.selector] = true; 
        restrictedSelectors[OwnerManager.swapOwner.selector] = true;
        restrictedSelectors[OwnerManager.changeThreshold.selector] = true;
        restrictedSelectors[GuardManager.setGuard.selector] = true;
    }

    /// @dev Performs a check on a function call to the safe
    /// @param data Data payload of Safe transaction.
    function checkTransaction(
        address,
        uint256,
        bytes memory data,
        Enum.Operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory,
        address
    ) external view override {

        // for now, simply disallow the calling of any of these selectors
        // In the future, may add nuances
        require(!restrictedSelectors[bytes4(data)], "GW001");
    }

    /// @dev Performs a check after the execution of the transaction
    function checkAfterExecution(bytes32, bool) external view override {}

    /// @dev Returns true if this contract implements the interface defined by interfaceId
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return
            interfaceId == type(Guard).interfaceId || // 0xe6d7a83a
            interfaceId == type(IERC165).interfaceId; // 0x01ffc9a7
    }

    fallback() external {
        // We don't revert on fallback to avoid issues in case of a Safe upgrade
        // E.g. The expected check method might change and then the Safe would be locked.
    }
}