// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

library BytesLib {
    string private constant OVERFLOW = "overflow";
    string private constant OUT_OF_BOUNDS = "out of bounds";

    function concat(bytes memory data, bytes memory seg)
        internal
        pure
        returns (bytes memory result)
    {
        assembly {
            let ptr := mload(0x40)
            let len := mload(data)

            mstore(ptr, len)

            let mc := add(ptr, 0x20)
            let end := add(mc, len)

            for {
                let i := add(data, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                i := add(i, 0x20)
            } {
                mstore(mc, mload(i))
            }

            len := mload(seg)
            mstore(ptr, add(len, mload(ptr)))

            mc := end
            end := add(mc, len)

            for {
                let i := add(seg, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                i := add(i, 0x20)
            } {
                mstore(mc, mload(i))
            }

            mstore(
                0x40,
                and(add(add(end, iszero(add(len, mload(data)))), 31), not(31))
            )

            result := ptr
        }
    }

    function slice(
        bytes memory data,
        uint256 offset,
        uint256 length
    ) internal pure returns (bytes memory result) {
        require(length + 31 >= length, OVERFLOW);
        require(offset + length >= offset, OVERFLOW);
        require(data.length >= offset + length, OUT_OF_BOUNDS);

        assembly {
            switch iszero(length)
            case 0 {
                result := mload(0x40)
                let lengthmod := and(length, 31)
                let mc := add(
                    add(result, lengthmod),
                    mul(0x20, iszero(lengthmod))
                )
                let end := add(mc, length)

                for {
                    let cc := add(
                        add(add(data, lengthmod), mul(0x20, iszero(lengthmod))),
                        offset
                    )
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(result, length)
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            default {
                result := mload(0x40)
                mstore(result, 0)
                mstore(0x40, add(result, 0x20))
            }
        }
    }

    function toAddress(bytes memory data, uint256 offset)
        internal
        pure
        returns (address result)
    {
        require(offset + 20 >= offset, OVERFLOW);
        require(data.length >= offset + 20, OUT_OF_BOUNDS);

        assembly {
            result := div(
                mload(add(add(data, 0x20), offset)),
                0x1000000000000000000000000
            )
        }
    }

    function toBytes32(bytes memory data, uint256 offset)
        internal
        pure
        returns (bytes32 result)
    {
        require(offset + 32 >= offset, OVERFLOW);
        require(data.length >= offset + 32, OUT_OF_BOUNDS);

        assembly {
            result := mload(add(add(data, 0x20), offset))
        }
    }

    function toString(bytes memory data, uint256 offset)
        internal
        pure
        returns (string memory result)
    {
        bytes32 value = toBytes32(data, offset);
        uint256 len = 32;

        uint256 i = 0;

        while (i < len && value[i] != 0) {
            unchecked {
                i = i + 1;
            }
        }

        bytes memory bytesArray = new bytes(i);

        for (i = 0; i < len && value[i] != 0; ) {
            bytesArray[i] = value[i];

            unchecked {
                i = i + 1;
            }
        }

        return string(bytesArray);
    }

    function toUint8(bytes memory data, uint256 offset)
        internal
        pure
        returns (uint8 result)
    {
        require(offset + 1 >= offset, OVERFLOW);
        require(data.length >= offset + 1, OUT_OF_BOUNDS);

        assembly {
            result := mload(add(add(data, 0x1), offset))
        }
    }

    function toUint16(bytes memory data, uint256 offset)
        internal
        pure
        returns (uint16 result)
    {
        require(offset + 2 >= offset, OVERFLOW);
        require(data.length >= offset + 2, OUT_OF_BOUNDS);

        assembly {
            result := mload(add(add(data, 0x2), offset))
        }
    }

    function toUint24(bytes memory data, uint256 offset)
        internal
        pure
        returns (uint24 result)
    {
        require(offset + 3 >= offset, OVERFLOW);
        require(data.length >= offset + 3, OUT_OF_BOUNDS);

        assembly {
            result := mload(add(add(data, 0x3), offset))
        }
    }

    function toUint32(bytes memory data, uint256 offset)
        internal
        pure
        returns (uint32 result)
    {
        require(offset + 4 >= offset, OVERFLOW);
        require(data.length >= offset + 4, OUT_OF_BOUNDS);

        assembly {
            result := mload(add(add(data, 0x4), offset))
        }
    }

    function toUint64(bytes memory data, uint256 offset)
        internal
        pure
        returns (uint64 result)
    {
        require(offset + 8 >= offset, OVERFLOW);
        require(data.length >= offset + 8, OUT_OF_BOUNDS);

        assembly {
            result := mload(add(add(data, 0x8), offset))
        }
    }

    function toUint96(bytes memory data, uint256 offset)
        internal
        pure
        returns (uint96 result)
    {
        require(offset + 12 >= offset, OVERFLOW);
        require(data.length >= offset + 12, OUT_OF_BOUNDS);

        assembly {
            result := mload(add(add(data, 0xc), offset))
        }
    }

    function toUint128(bytes memory data, uint256 offset)
        internal
        pure
        returns (uint128 result)
    {
        require(offset + 16 >= offset, OVERFLOW);
        require(data.length >= offset + 16, OUT_OF_BOUNDS);

        assembly {
            result := mload(add(add(data, 0x10), offset))
        }
    }

    function toUint256(bytes memory data, uint256 offset)
        internal
        pure
        returns (uint256 result)
    {
        require(offset + 32 >= offset, OVERFLOW);
        require(data.length >= offset + 32, OUT_OF_BOUNDS);

        assembly {
            result := mload(add(add(data, 0x20), offset))
        }
    }
}

/* solhint-enable */
