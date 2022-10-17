// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/libraries/SafeERC20.sol";
import "src/libraries/Wrapper.sol";

abstract contract Payment {
    using SafeERC20 for address;
    using Wrapper for address;

    address public immutable wrappedNative;

    constructor(address _wrappedNative) {
        wrappedNative = _wrappedNative;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    function wrap(address recipient, uint256 value) internal {
        wrappedNative.wrap(value);

        if (recipient != address(this))
            wrappedNative.safeTransfer(recipient, value);
    }

    function unwrap(address recipient, uint256 value) internal {
        wrappedNative.unwrap(value);

        if (recipient != address(this)) recipient.safeTransferNative(value);
    }

    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (payer == address(this)) token.safeTransfer(recipient, value);
        else token.safeTransferFrom(payer, recipient, value);
    }

    function pull(
        address token,
        address recipient,
        uint256 value
    ) internal {
        if (value == type(uint256).max) value = token.getBalanceOf(recipient);

        if (token.isNative()) wrap(recipient, value);
        else token.safeTransferFrom(msg.sender, recipient, value);
    }
}
