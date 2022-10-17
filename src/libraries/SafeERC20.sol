// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

library SafeERC20 {
    string private constant UNKNOWN = "???";

    function safeApprove(
        address token,
        address spender,
        uint256 amount
    ) internal {
        if (isNative(token)) return;

        bool success;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)

            mstore(
                ptr,
                0x095ea7b300000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 0x4), spender)
            mstore(add(ptr, 0x24), amount)

            success := and(
                or(
                    and(eq(mload(0), 0x1), gt(returndatasize(), 0x1f)),
                    iszero(returndatasize())
                ),
                call(gas(), token, 0, ptr, 0x44, 0, 0x20)
            )
        }

        require(success, "SA");
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (isNative(token)) {
            require(msg.value >= amount, "STFN");
            return;
        }

        bool success;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)

            mstore(
                ptr,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 0x4), from)
            mstore(add(ptr, 0x24), to)
            mstore(add(ptr, 0x44), amount)

            success := and(
                or(
                    and(eq(mload(0), 0x1), gt(returndatasize(), 0x1f)),
                    iszero(returndatasize())
                ),
                call(gas(), token, 0, ptr, 0x64, 0, 0x20)
            )
        }

        require(success, "STF");
    }

    function safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (!isNative(token)) _safeTransfer(token, to, amount);
        else safeTransferNative(to, amount);
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) private {
        bool success;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)

            mstore(
                ptr,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 0x4), to)
            mstore(add(ptr, 0x24), amount)

            success := and(
                or(
                    and(eq(mload(0), 0x1), gt(returndatasize(), 0x1f)),
                    iszero(returndatasize())
                ),
                call(gas(), token, 0, ptr, 0x44, 0, 0x20)
            )
        }

        require(success, "ST");
    }

    function safeTransferNative(address to, uint256 amount) internal {
        bool success;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "STN");
    }

    function getAllowance(
        address token,
        address owner,
        address spender
    ) internal view returns (uint256 value) {
        if (isNative(token)) return type(uint256).max;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)

            mstore(
                ptr,
                0xdd62ed3e00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 0x4), owner)
            mstore(add(ptr, 0x24), spender)

            if iszero(staticcall(gas(), token, ptr, 0x44, 0, 0x20)) {
                revert(0, 0)
            }

            value := mload(0)
        }
    }

    function getBalanceOf(address token, address account)
        internal
        view
        returns (uint256 value)
    {
        if (isNative(token)) return account.balance;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)

            mstore(
                ptr,
                0x70a0823100000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 0x4), account)

            if iszero(staticcall(gas(), token, ptr, 0x24, 0, 0x20)) {
                revert(0, 0)
            }

            value := mload(0)
        }
    }

    function getTotalSupply(address token)
        internal
        view
        returns (uint256 value)
    {
        if (isNative(token)) return 0;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)

            mstore(
                ptr,
                0x18160ddd00000000000000000000000000000000000000000000000000000000
            )

            if iszero(staticcall(gas(), token, ptr, 0x4, 0, 0x20)) {
                revert(0, 0)
            }

            value := mload(0)
        }
    }

    function getDecimals(address token) internal view returns (uint8 value) {
        if (isNative(token)) return 18;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)

            mstore(
                ptr,
                0x313ce56700000000000000000000000000000000000000000000000000000000
            )

            if iszero(staticcall(gas(), token, ptr, 0x4, 0, 0x20)) {
                revert(0, 0)
            }

            value := mload(0)
        }
    }

    function getSymbol(address token) internal view returns (string memory) {
        if (isNative(token)) return "NATIVE";

        (bool success, bytes memory returnData) = token.staticcall(
            abi.encodeWithSelector(0x95d89b41)
        );

        return success ? bytesToString(returnData) : UNKNOWN;
    }

    function getName(address token) internal view returns (string memory) {
        if (isNative(token)) return "Native";

        (bool success, bytes memory returnData) = token.staticcall(
            abi.encodeWithSelector(0x06fdde03)
        );

        return success ? bytesToString(returnData) : UNKNOWN;
    }

    function bytesToString(bytes memory data)
        internal
        pure
        returns (string memory)
    {
        if (data.length == 32) {
            uint256 i = 0;

            while (i < 32 && data[i] != 0) {
                unchecked {
                    i = i + 1;
                }
            }

            bytes memory bytesArray = new bytes(i);

            for (i = 0; i < 32 && data[i] != 0; ) {
                bytesArray[i] = data[i];

                unchecked {
                    i = i + 1;
                }
            }

            return string(bytesArray);
        } else if (data.length >= 64) return abi.decode(data, (string));
        else return UNKNOWN;
    }

    function isNative(address token) internal pure returns (bool) {
        return token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    function isZeroAddress(address token) internal pure returns (bool) {
        return token == address(0);
    }
}
