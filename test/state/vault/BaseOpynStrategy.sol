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
    OpynStrategy public strategyTemplate;
    OpynStrategy public strategy;
    BeakerPeriodicVault public vault;
    IController public gammaController;
    IOtokenFactory public otokenFactory;
    IMarginPool public marginPool;

    // accounts
    address public keeper = vm.addr(uint256(keccak256("keeper")));
    address public counterparty = vm.addr(uint256(keccak256("counterparty")));

    bytes32 public constant OPYN_STRAT_IMPL_ID = keccak256("OpynStrategyV1");

    // contract addresses
    address public constant GAMMA_CONTROLLER = address(0x4ccc2339F87F6c59c6893E1A678c2266cA58dC72);
    address public constant OTOKEN_FACTORY = address(0x7C06792Af1632E77cb27a558Dc0885338F4Bdf8E);
    address public constant MARGIN_POOL = address(0x5934807cC0654d46755eBd2848840b616256C6Ef);

    function _assertVaultSetup() private {
        assertEq(vault.governance(), governance);
        assertEq(vault.keeper(), keeper);
        assertEq(vault.strategy(), address(strategy));
        assertEq(vault.asset(), address(weth));
        assertEq(vault.factory(), address(vaultFactory));
        assertEq(vault.router(), address(0));
        assertEq(vault.cap(), 1000 ether);
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(Bytes32Strings.bytes32ToString("vault-0"))));
        assertEq(vault.symbol(), "BLP-0");
    }

    function _assertStrategySetup() private {
        assertEq(strategy.beaker(), address(vault));
        assertEq(strategy.governance(), governance);
        assertEq(strategy.asset(), address(weth));
        assertEq(address(strategy.swapRouter()), address(0));
        assertEq(strategy.period(), 7 days);
        assertEq(strategy.usdc(), address(usdc));
        assertEq(address(strategy.controller()), address(gammaController));
        assertEq(address(strategy.oTokenFactory()), address(otokenFactory));
        assertEq(strategy.marginPool(), address(marginPool));
    }

    function labelAddresses() public virtual override {
        super.labelAddresses();

        vm.label(address(strategyTemplate), "strategyTemplate");
        vm.label(address(strategy), "opynStrategy");
        vm.label(address(vault), "opynVault");
        vm.label(address(gammaController), "gammaController");
        vm.label(address(otokenFactory), "otokenFactory");
        vm.label(address(marginPool), "marginPool");
        vm.label(address(keeper), "keeper");
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
        strategyTemplate = new OpynStrategy(address(weth), governance);

        // deal the counterparty some WETH and USDC
        deal(address(weth), counterparty, 10000 ether);
        deal(address(usdc), counterparty, 10000e6);

        // impersonate the governance account
        vm.startPrank(governance);

        // set the strategy as an implementation on the factory
        vaultFactory.setImplementation(OPYN_STRAT_IMPL_ID, address(strategyTemplate));

        // create the vault params
        bytes memory vaultParams = abi.encodePacked(
            keeper,                                     // _keeper: keeper of the beaker
            address(0),                                 // _router (address): the swap router address
            uint256(1000 ether),                        // _capacity: max capacity of the underlying asset for the vault
            address(weth),                              // _asset (address): the underlying asset handled by the vault
            Bytes32Strings.bytes32ToString("vault-0")   // _tokenName: name of the vault token
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
        (address _vault, address _strategy) = vaultFactory.deploy(VAULT_IMPL_ID, OPYN_STRAT_IMPL_ID, vaultParams, strategyParams);

        // set vault and strategy contracts
        vault = BeakerPeriodicVault(payable(_vault));
        strategy = OpynStrategy(_strategy);

        // switch prank to the counterparty
        changePrank(counterparty);

        // allow the strategy to be a operator for the counterparty
        gammaController.setOperator(address(strategy), true);

        // assert vault setup
        _assertVaultSetup();

        // assert strategy setup
        _assertStrategySetup();

        // stop the impersonation
        vm.stopPrank();

        // label addresses
        labelAddresses();
    }

}