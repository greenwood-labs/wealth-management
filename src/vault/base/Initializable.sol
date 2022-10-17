// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/IInitializer.sol";

abstract contract Initializable is IInitializer {
    bool private _initialized;

    bool private _initializing;

    modifier initializer() {
        require(_initializing || !_initialized, "already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    modifier onlyInitializing() {
        require(_initializing, "not initializing");
        _;
    }
}
