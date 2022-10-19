// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/Gamma/IOracle.sol";

import "test/state/vault/BaseOpynStrategy.sol";
import "test/mocks/Opyn/mockPricer.sol";

contract BaseMockPricer is BaseOpynStrategy {
    IOracle public gammaOracle;
    MockPricer public mockWethPricer;
    MockPricer public mockLongCallPricer;
    MockPricer public mockLongPutPricer;
    MockPricer public mockShortPutPricer;

    // accounts
    address public gammaOracleOwner = address(0x2FCb2fc8dD68c48F406825255B4446EDFbD3e140);

    // contract addresses
    address public constant GAMMA_ORACLE = address(0x789cD7AB3742e23Ce0952F6Bc3Eb3A73A0E08833);

    function setMockOtokenAssetPricers(
        address longCallOtoken,
        address longPutOtoken,
        address shortPutOtoken
    ) public {

        // impersonate the gamma oracle owner
        vm.startPrank(gammaOracleOwner);

        // deploy mock oToken pricers
        mockLongCallPricer = new MockPricer(longCallOtoken, GAMMA_ORACLE);
        mockLongPutPricer = new MockPricer(longPutOtoken, GAMMA_ORACLE);
        mockShortPutPricer = new MockPricer(shortPutOtoken, GAMMA_ORACLE);

        // set the mock asset pricers on the gamma oracle
        gammaOracle.setAssetPricer(longCallOtoken, address(mockLongCallPricer));
        gammaOracle.setAssetPricer(longPutOtoken, address(mockLongPutPricer));
        gammaOracle.setAssetPricer(shortPutOtoken, address(mockShortPutPricer));

        // stop the impersonation
        vm.stopPrank();
    }

    function labelAddresses() public virtual override {
        super.labelAddresses();

        vm.label(gammaOracleOwner, "gammaOracleOwner");
        vm.label(address(gammaOracle), "gammaOracle");
    }

    function setUp() public virtual override {
        super.setUp();

        // gamma oracle instance
        gammaOracle = IOracle(GAMMA_ORACLE);

        // impersonate the gamma oracle owner
        vm.startPrank(gammaOracleOwner);

        // create weth mock pricer
        mockWethPricer = new MockPricer(address(weth), GAMMA_ORACLE);

        // set the initial mock price of weth to $180
        mockWethPricer.setPrice(180e8);

        // set the mock weth pricer on the gamma oracle
        gammaOracle.setAssetPricer(address(weth), address(mockWethPricer));

        // stop the impersonation
        vm.stopPrank();

        // assert mock setup is correct
        assertEq(gammaOracle.getPricer(address(weth)), address(mockWethPricer));
        assertEq(gammaOracle.getPrice(address(weth)), 180e8);

        // label addresses
        labelAddresses();
    }

}