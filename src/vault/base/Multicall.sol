// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract Multicall {
    function multicall(bytes[] memory calls)
        external
        payable
        returns (bytes[] memory returnData)
    {
        uint256 len = calls.length;
        returnData = new bytes[](len);

        for (uint256 i; i < len; ) {
            bool success;

            // solhint-disable-next-line avoid-low-level-calls
            (success, returnData[i]) = address(this).delegatecall(calls[i]);

            if (!success) getRevertMsg(returnData[i]);

            unchecked {
                i = i + 1;
            }
        }
    }

    function getRevertMsg(bytes memory returnData)
        internal
        pure
        returns (string memory)
    {
        if (returnData.length < 68) return "tx reverted silently";

        // solhint-disable-next-line no-inline-assembly
        assembly {
            returnData := add(returnData, 0x04)
        }

        return abi.decode(returnData, (string));
    }
}
