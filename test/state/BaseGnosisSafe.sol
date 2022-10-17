// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "solmate/tokens/ERC20.sol";
import "safe-contracts/GnosisSafe.sol";
import "safe-contracts/proxies/GnosisSafeProxyFactory.sol";

import "test/utils/GnosisUtils.sol";

contract BaseGnosisSafe is Test {
    ERC20 public weth;
    GnosisSafe public safe;
    GnosisSafeProxyFactory public safeFactory;

    // private keys
    uint256 public privKeyClient0 = 1;
    uint256 public privKeyClient1 = 2;
    uint256 public privKeyManager = 3;
    uint256 public privKeyNewOwner = 4;

    // owners
    address public client0 = vm.addr(privKeyClient0);
    address public client1 = vm.addr(privKeyClient1);
    address public manager = vm.addr(privKeyManager);
    address public newOwner = vm.addr(privKeyNewOwner);

    // contract addresses
    address public constant GNOSIS_SAFE_PROXY_FACTORY = 0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2;
    address public constant GNOSIS_SAFE_SINGLETON = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;
    address public constant GNOSIS_SAFE_FALLBACK_HANDLER = 0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function labelAddresses() public virtual {
        vm.label(client0, "client0");
        vm.label(client1, "client1");
        vm.label(manager, "manager");
        vm.label(newOwner, "newOwner");

        vm.label(address(weth), "WETH");
        vm.label(address(safe), "safe");
        vm.label(address(safeFactory), "safeFactory");
    }

    function _gnosisSetupCallEncoding(
        address[] memory owners,
        uint256 threshold,
        address to,
        bytes memory data,
        address fallbackManager,
        address paymentToken,
        uint256 payment, 
        address payable paymentReceiver
    ) internal pure returns (bytes memory) {
        return abi.encodeCall(
            GnosisSafe.setup, 
            (
                owners,
                threshold,
                to,
                data,
                fallbackManager,
                paymentToken,
                payment,
                paymentReceiver
            )
        );
    }

    function setUp() public virtual {

        // safe factory instance
        safeFactory = GnosisSafeProxyFactory(GNOSIS_SAFE_PROXY_FACTORY);

        // weth instance
        weth = ERC20(WETH);

        // assert safe factory was properly retrieved
        assertTrue(address(safeFactory) != address(0));

        // gnosis safe setup() values
        address[] memory owners = new address[](3);
        owners[0] = client0;
        owners[1] = client1;
        owners[2] = manager;
        uint256 threshold = 2;
        address to = address(0);
        bytes memory data = "";
        address fallbackManager = GNOSIS_SAFE_FALLBACK_HANDLER;
        address paymentToken = address(0);
        uint256 payment = 0;
        address payable paymentReceiver = payable(address(0));

        // create initializerPayload byte data to execute GnosisSafe.setup() upon deployment
        bytes memory initializerPayload = _gnosisSetupCallEncoding(
            owners,
            threshold,
            to,
            data,
            fallbackManager,
            paymentToken,
            payment,
            paymentReceiver
        );

        // salt nonce for deployment
        uint256 gnosisSaltNonce = 1648664322100;

        // deploy a safe proxy using initializer values for the GnosisSafe.setup() call
        safe = GnosisSafe(payable(address(safeFactory.createProxyWithNonce(
            GNOSIS_SAFE_SINGLETON, 
            initializerPayload, 
            gnosisSaltNonce
        ))));

        // deal some WETH to the safe
        deal(WETH, address(safe), 100 ether);

        // assert Gnosis Safe proxy deployment was successful
        assertTrue(address(safe) != address(0));
        assertTrue(safe.isOwner(client0));
        assertTrue(safe.isOwner(client1));
        assertTrue(safe.isOwner(manager));
        assertEq(safe.getOwners().length, 3);
        assertEq(safe.getThreshold(), 2);
        assertEq(weth.balanceOf(address(safe)), 100 ether);

        // label addresses
        labelAddresses();
    }
}
