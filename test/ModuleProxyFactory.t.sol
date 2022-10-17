// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/GreenwoodModule.sol";
import "test/state/BaseModuleProxyFactory.sol";

contract ModuleProxyFactoryTest is BaseModuleProxyFactory {

    function testDeployModule() public {

        // salt value
        uint256 moduleProxySalt = 1234567890;

        // setup() call to be run after module proxy is deployed
        bytes memory setupCall = abi.encodeCall(
            GreenwoodModule.setup, 
            (client0, address(safe), address(guard))
        );
        
        // create Greenwood module proxy instance, and call setup() upon deployment
        address deployedModule = moduleFactory.deployModule(
            address(moduleTemplate), 
            setupCall, 
            moduleProxySalt 
        );

        // retreive the proxy bytecode from the factory
        bytes memory proxyBytecode = moduleFactory.getDeploymentBytecode(address(moduleTemplate));

        // compute the expected deployment address for the module
        address create2ComputedAddress = address(uint160(uint256(keccak256(
            abi.encodePacked(
                bytes1(0xff), 
                address(moduleFactory), 
                keccak256(abi.encodePacked(keccak256(setupCall), moduleProxySalt)), 
                keccak256(proxyBytecode)
            )
        ))));

        // assert the deployed module has the expected address
        assertEq(deployedModule, create2ComputedAddress);

        // assert the deployed module has the expected bytecode
        assertEq(
            abi.encodePacked(hex"602d8060093d393df3", deployedModule.code), 
            proxyBytecode
        );
    }
}