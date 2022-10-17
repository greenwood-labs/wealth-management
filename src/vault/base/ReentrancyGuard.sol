// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract ReentrancyGuard {
    uint256 private constant UNLOCKED = 1;
    uint256 private constant LOCKED = 2;

    uint256 private locked = UNLOCKED;

    modifier unlocked() {
        _unlocked();

        locked = LOCKED;

        _;

        locked = UNLOCKED;
    }

    function _unlocked() internal view {
        require(locked != LOCKED, "locked");
    }
}
