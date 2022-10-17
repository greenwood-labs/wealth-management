// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Vm.sol";

library GnosisUtils {

    address constant private VM_ADDRESS =
        address(bytes20(uint160(uint256(keccak256('hevm cheat code')))));
    Vm private constant vm = Vm(VM_ADDRESS);

    function buildGnosisSignatures(
        bytes memory privateKeys, 
        bytes32 transactionHash,
        uint256 numKeys
    ) external returns (bytes memory gnosisSignatures) {

        uint256 i;
        for (i = 0; i < numKeys; i++) {

            uint256 privateKey;
            assembly {
                let keyPosition := mul(0x20, i)
                privateKey := mload(add(privateKeys, add(keyPosition, 0x20)))
            }

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, transactionHash);
            gnosisSignatures = abi.encodePacked(gnosisSignatures, abi.encodePacked(r, s, v));
        }
    }
}