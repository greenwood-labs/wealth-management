// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract AccessControl {
    mapping(address => bool) private _authorized;

    address public immutable governance;

    modifier restricted() {
        _isAuthorized(msg.sender);
        _;
    }

    modifier onlyGovernance() {
        _isGovernance();
        _;
    }

    constructor(address _governance) {
        governance = _governance;
    }

    function execute(
        address target,
        bytes memory payload,
        uint256 value
    ) external payable {
        _isGovernance();

        value == type(uint256).max ? address(this).balance : value;

        require(value <= address(this).balance, "22");

        // solhint-disable-next-line
        (bool success, ) = target.call{ value: value }(payload);

        require(success, "23");
    }

    function setAuthority(address account, bool authority) external {
        _isGovernance();
        _setAuthority(account, authority);
    }

    function _setAuthority(address account, bool authority) internal {
        _authorized[account] = authority;
    }

    function _isAuthorized(address account) internal view {
        require(account == governance || _authorized[account], "!authorized");
    }

    function _isGovernance() internal view {
        require(msg.sender == governance, "!governance");
    }
}
