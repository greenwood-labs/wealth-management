// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

library Wrapper {
    function wrap(address wrappedNative, uint256 value) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            if iszero(value) {
                revert(0, 0)
            }

            let ptr := mload(0x40)

            mstore(
                ptr,
                0xd0e30db000000000000000000000000000000000000000000000000000000000
            )

            if iszero(call(gas(), wrappedNative, value, ptr, 0x4, 0, 0)) {
                revert(0, 0)
            }
        }
    }

    function unwrap(address wrappedNative, uint256 value) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            if iszero(value) {
                revert(0, 0)
            }

            let ptr := mload(0x40)

            mstore(
                ptr,
                0x2e1a7d4d00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 4), value)

            if iszero(call(gas(), wrappedNative, 0, ptr, 0x24, 0, 0)) {
                revert(0, 0)
            }
        }
    }
}
