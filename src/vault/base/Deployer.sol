// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/IInitializer.sol";

abstract contract Deployer {
    mapping(bytes32 => address) internal _implementations;
    mapping(address => address) internal _implementationOf;

    function _deploy(
        bytes32 id,
        bytes32 salt,
        bytes memory params
    ) internal returns (address instance) {
        address implementation = _implementations[id];
        require(implementation != address(0), "!implementation");

        bytes20 targetBytes = bytes20(implementation);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), targetBytes)
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            instance := create2(0, ptr, 0x37, salt)
        }

        require(instance != address(0), "!instance");

        _implementationOf[instance] = implementation;

        require(IInitializer(instance).initialize(params), "!initialize");
    }

    function _computeAddress(bytes32 id, bytes32 salt)
        internal
        view
        returns (address instance)
    {
        address implementation = _implementations[id];
        address deployer = address(this);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000
            )
            mstore(add(ptr, 0x38), shl(0x60, deployer))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            instance := keccak256(add(ptr, 0x37), 0x55)
        }
    }

    function _getSalt(bytes32 id, uint256 nonce)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(id, nonce));
    }

    function implementations(bytes32 id) external view returns (address) {
        return _implementations[id];
    }

    function implementationOf(address clone) external view returns (address) {
        return _implementationOf[clone];
    }
}
