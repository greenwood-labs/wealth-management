// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

library Bytes32Strings {
  
    function bytes32ToString(bytes32 value)
        internal
        pure 
        returns (string memory) {

            // create a bytes array of size 32
            bytes memory bytesArray = new bytes(32);

            // convert a fixed-length bytes32 to a dynamic bytes array of size 32
            for (uint256 i; i < 32; i++) {
                bytesArray[i] = value[i];
            }

            // convert to string
            return string(bytesArray);
        }
}
