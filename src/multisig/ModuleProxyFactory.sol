// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

/// @title Greenwood Module Proxy Factory - A factory contract to deploy greenwood module proxy instances
contract ModuleProxyFactory {

    /// @dev Uses create2 to deploy a new module proxy contract
    /// @param template The template contract to deploy a proxy from
    /// @param initializer The data to call on the newly deployed contract
    /// @param saltNonce The unique salt nonce to use for deployment of the module
    function createProxy(
        address template,
        bytes memory initializer,
        uint256 saltNonce
    ) internal returns (address proxy) {

        // generate a salt for create2
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));

        // get deployment bytecode
        bytes memory deploymentBytecode = getDeploymentBytecode(template);

        // use create2 to deploy the proxy contract
        assembly {
            proxy := create2(0, add(deploymentBytecode, 0x20), mload(deploymentBytecode), salt)
        }

        require(address(proxy) != address(0), "GW003");
    }

    /// @dev Gets the deployment bytecode for a template contract
    /// @param template The template contract to get the deployment bytecode for
    function getDeploymentBytecode(address template) public pure returns (bytes memory) {

        // insert template address into minimal proxy bytecode
        return abi.encodePacked(
            hex"602d8060093d393df3363d3d373d3d3d363d73",
            template,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
    }
    /// @dev Deploys a new Greenwood module proxy contract using the minimal proxy pattern, and then
    ///      calls the initializer data on the newly deployed contract
    /// @param template The template contract to deploy a proxy from
    /// @param initializer The data to call on the newly deployed contract
    /// @param saltNonce The unique salt nonce to use for deployment of the module
    function deployModule(
        address template,
        bytes memory initializer,
        uint256 saltNonce
    ) external returns (address proxyModule) {

        // deploy the proxy module contract
        proxyModule = createProxy(template, initializer, saltNonce);

        // call the initializer transaction on the proxy module
        if (initializer.length > 0) {
            assembly {
                if eq(call(gas(), proxyModule, 0, add(initializer, 0x20), mload(initializer), 0, 0), 0) {
                    revert(0, 0)
                }
            }
        }
    }
}