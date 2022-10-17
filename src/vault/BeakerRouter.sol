// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/vault/base/Governed.sol";
import "src/vault/base/Multicall.sol";
import "src/vault/base/Payment.sol";

contract BeakerRouter is Governed, Multicall, Payment {
    constructor(address _governance, address _wrappedNative)
        Governed(_governance)
        Payment(_wrappedNative)
    {}
}
