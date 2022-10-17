// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract Governed {
    address public immutable governance;

    modifier onlyGovernance() {
        require(_isGovernance(), "sender not governance");
        _;
    }

    constructor(address _governance) {
        governance = _governance;
    }

    function _isGovernance() internal view returns (bool) {
        return msg.sender == governance;
    }
}
