// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "test/state/vault/BaseVaultFactory.sol";

import "src/interfaces/Gamma/IController.sol";
import "src/interfaces/Gamma/IMarginPool.sol";
import "src/interfaces/Gamma/IOracle.sol";
import "src/interfaces/Gamma/IOToken.sol";
import "src/interfaces/Gamma/IOTokenFactory.sol";

import "src/vault/strategies/Opyn/OpynStrategy.sol";
import "src/vault/BeakerPeriodicVault.sol";
import "src/libraries/Bytes32Strings.sol";

contract BaseOpynStrategy is BaseVaultFactory {
    OpynStrategy public strategy;
    BeakerPeriodicVault public vault;
    IController public gammaController;
    IOtokenFactory public otokenFactory;
    IMarginPool public marginPool;

    address public keeper = vm.addr(1234567);

    bytes32 public constant OPYN_STRAT_IMPL_ID = keccak256("OpynStrategyV1");

    address public constant GAMMA_CONTROLLER = address(0x4ccc2339F87F6c59c6893E1A678c2266cA58dC72);
    address public constant GAMMA_ORACLE = address(0x789cD7AB3742e23Ce0952F6Bc3Eb3A73A0E08833);
    address public constant OTOKEN_FACTORY = address(0x7C06792Af1632E77cb27a558Dc0885338F4Bdf8E);
    address public constant MARGIN_POOL = address(0x5934807cC0654d46755eBd2848840b616256C6Ef);
    address public constant PREMIUM_PRICER = address(0x5bA2A42b74A72a1A3ccC37CF03802a0b7A551139);

    function labelAddresses() public virtual override {
        super.labelAddresses();

        vm.label(address(strategy), "opynStrategy");
        vm.label(address(vault), "opynVault");
    }

    function setUp() public virtual override {
        super.setUp();

        // get gamma controller instance
        gammaController = IController(GAMMA_CONTROLLER);

        // get oToken factory instance
        otokenFactory = IOtokenFactory(OTOKEN_FACTORY);

        // get margin pool instance
        marginPool = IMarginPool(MARGIN_POOL);

        // deploy the strategy template
        strategy = new OpynStrategy(address(weth), governance);

        // set the strategy as an implementation on the factory
        vaultFactory.setImplementation(OPYN_STRAT_IMPL_ID, address(strategy));

        // create the vault params
        bytes memory vaultParams = abi.encodePacked(
            keeper,                                 // _keeper: keeper of the beaker
            address(0),                             // _router (address): the swap router address
            uint256(1000 ether),                    // _capacity: max capacity of the underlying asset for the vault
            address(weth),                          // _asset (address): the underlying asset handled by the vault
            Bytes32Strings.bytes32ToString("GLP")   // _tokenName: name of the vault token
        );

        // create the strategy params
        bytes memory strategyParams = abi.encodePacked(
            address(weth),              //  _asset: the asset handled by the strategy
            uint256(7 days),            //  _period: length of time between rounds
            address(gammaController),   //  _controller (address): Opyn options Gamma controller
            address(otokenFactory),     //  _oTokenFactory (address): factory contract for oTokens
            address(usdc),              //  _usdc: the address of the USDC token
            address(marginPool),        //  _marginPool (address): address for the Opyn margin pool
            address(0)                  //  _swapRouter: the swap router address
        );

        // deploy the vault and strategy contracts together
        vaultFactory.deploy(VAULT_IMPL_ID, OPYN_STRAT_IMPL_ID, vaultParams, strategyParams);

        // label addresses
        labelAddresses();
    }

}