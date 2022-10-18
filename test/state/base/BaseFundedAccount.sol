// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "solmate/tokens/ERC20.sol";

contract BaseFundedAccount is Test {
    ERC20 public weth;
    ERC20 public dai;
    ERC20 public usdc;

    // private keys
    uint256 public privKey0 = 1;
    uint256 public privKey1 = 2;
    uint256 public privKey2 = 3;
    uint256 public privKey3 = 4;

    // EOAs
    address public user0 = vm.addr(privKey0);
    address public user1 = vm.addr(privKey1);
    address public user2 = vm.addr(privKey2);
    address public user3 = vm.addr(privKey3);

    // contract addresses
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function labelAddresses() public virtual {
        vm.label(user0, "user0");
        vm.label(user1, "user1");
        vm.label(user2, "user2");
        vm.label(user3, "user3");

        vm.label(address(weth), "WETH");
        vm.label(address(dai), "DAI");
        vm.label(address(usdc), "USDC");
    }

    function setUp() public virtual {

        // ERC20 instances
        weth = ERC20(WETH);
        dai = ERC20(DAI);
        usdc = ERC20(USDC);

        // deal some ERC20s to the EOAs
        for (uint256 i = 1; i <= 4; i++) {
            deal(WETH, vm.addr(i), 100 ether);
            deal(DAI,  vm.addr(i), 10000e18);
            deal(USDC, vm.addr(i), 10000e6);

            // assert that tokens were dealt properly
            assertEq(weth.balanceOf(vm.addr(i)), 100 ether);
            assertEq(dai.balanceOf(vm.addr(i)), 10000e18);
            assertEq(usdc.balanceOf(vm.addr(i)), 10000e6);
        }

        // label addresses
        labelAddresses();
    }
}