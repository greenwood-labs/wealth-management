// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/ISwapRouter.sol";

import "src/interfaces/Gamma/IController.sol";
import "src/interfaces/Gamma/IOToken.sol";
import "src/interfaces/Gamma/IOTokenFactory.sol";

import "src/libraries/SafeERC20.sol";
import "src/libraries/BytesLib.sol";

import "src/vault/strategies/template/PeriodicStrategy.sol";

contract OpynStrategy is PeriodicStrategy {
    using SafeERC20 for address;
    using BytesLib for bytes;

    /************************************************
     *  Storage
     ***********************************************/

    /// @notice Opyn options Gamma controller
    IController public controller;

    /// @notice factory contract for oTokens
    IOtokenFactory public oTokenFactory;

    /// @notice router for swapping tokens
    ISwapRouter public swapRouter;

    /// @notice address of the long call oToken
    address public longCallOtoken;

    /// @notice address of the long put oToken
    address public longPutOtoken;

    /// @notice address of the short put oToken
    address public shortPutOtoken;

    /// @notice expiry of the current round of oTokens
    uint256 public currentExpiry;

    /// @notice address for the USDC token
    address public usdc;

    /// @notice address for the Opyn margin pool
    address public marginPool;

    /// @notice address to exchange oTokens with
    address public counterparty;

    /// @notice vault ID of long call and short put oToken vault
    uint256 public longCallVaultID;
    uint256 public shortPutVaultID;

    /// @notice collaterals deposited for the current round
    uint256 public usdcPutCollateral;
    uint256 public wethCallCollateral;

    /************************************************
     *  CONSTRUCTOR & INITIALIZATION
     ***********************************************/

    /// @notice constructs the strategy
    /// @param _wnative the wrapped native token of the chain
    /// @param _governance governance address to manage strategy
    constructor(
        address _wnative,
        address _governance
    ) PeriodicStrategy(_wnative, _governance) {}

    /// @notice Initializes the contract with storage variables
    /// @param _params parameters to initialize the beaker
    //  _beaker (address): the beaker contract
    //  _asset (address): the asset handled by the strategy
    //  _period (uint256): length of time between rounds
    //  _controller (address): Opyn options Gamma controller
    //  _oTokenFactory (address): factory contract for oTokens
    //  _usdc (address): the address of the USDC token
    //  _marginPool (address): address for the Opyn margin pool
    //  _swapRouter (address): the swap router address
    function initialize(bytes memory _params)
        external
        override
        initializer
        returns (bool)
    {
        beaker = _params.toAddress(0x00);
        asset = _params.toAddress(0x14);
        period = _params.toUint256(0x28);

        controller = IController(_params.toAddress(0x48));
        oTokenFactory = IOtokenFactory(_params.toAddress(0x5C));
        usdc = _params.toAddress(0x70);
        marginPool = _params.toAddress(0x84);
        swapRouter = ISwapRouter(_params.toAddress(0x98));

        strategyState.round = 1;

        // set up approvals
        _giveAllowances();

        return true;
    }

    /************************************************
     *  STRATEGY OPERATIONS
     ***********************************************/

    /// @notice Creates 3 oTokens to used to produce a buffered note structured product
    /// @param longCallStrike strike price of the long call option
    /// @param longPutStrike strike price of the long put option
    /// @param shortPutStrike strike price of the short put option
    /// @param expiry date of expiry for the options
    /// @param usdcCollateral amount of USDC to be used as collateral for the long put option vault
    /// @param wethCollateral amount of WETH to be used as collateral for the long call option vault
    /// @param onBehalfOf the counterparty to receive sold short put oTokens
    function createOtokens(
        uint256 longCallStrike,
        uint256 longPutStrike,
        uint256 shortPutStrike,
        uint256 expiry,
        uint256 usdcCollateral,
        uint256 wethCollateral,
        address onBehalfOf
    ) external {

        // get the next valid expiration date
        uint256 expiryDate = _getNextFriday(expiry);

        // create all 3 oTokens
        longCallOtoken = _getOtoken(wrappedNative, usdc, wrappedNative, longCallStrike, expiryDate, false);
        longPutOtoken = _getOtoken(wrappedNative, usdc, usdc, longPutStrike, expiryDate, true);
        shortPutOtoken = _getOtoken(wrappedNative, usdc, usdc, shortPutStrike, expiryDate, true);    

        // set current expiry
        currentExpiry = expiryDate;

        // set counterparty
        counterparty = onBehalfOf;

        // set collaterals
        usdcPutCollateral = usdcCollateral;
        wethCallCollateral = wethCollateral;

        // pull funds from msg.sender
        usdc.safeTransferFrom(msg.sender, address(this), usdcPutCollateral);
        wrappedNative.safeTransferFrom(msg.sender, address(this), wethCallCollateral);
    }

    /// @notice Rolls the strategy's funds into a new strategy position
    function rollToNextPosition() external override onlyBeaker returns (uint256) {

        uint256 underlyingFunds = asset.getBalanceOf(address(this)) - wethCallCollateral;

        uint256 mintShares = _rollToNextPosition(underlyingFunds);
        
        // create the next position
        _createBufferedNote();
        
        // return the number of shares to mint
        return mintShares;
    }

    /// @notice Closes the existing position and sets up next position
    function commitAndClose() external override onlyBeaker {
        // redeem long call oTokens -> get back WETH
        _redeemOtokens(longCallOtoken, counterparty, longCallVaultID);

        // settle short put oTokens + redeem long put oTokens -> get back USDC
        _settleVault(address(this), address(this), shortPutVaultID);

        // convert USDC to WETH, if this contract holds USDC
        uint256 usdcBalance = usdc.getBalanceOf(address(this));
        if (usdcBalance > 0) {
            swapRouter.swap(usdc, asset, usdcBalance, address(this));
        }

        // reset oTokens
        delete longCallOtoken;
        delete longPutOtoken;
        delete shortPutOtoken;

        // reset counterparty, expiry, and collaterals
        delete counterparty;
        delete currentExpiry;
        delete usdcPutCollateral;
        delete wethCallCollateral;
    }

    /************************************************
     *  INTERNAL FUNCTIONS
     ***********************************************/

    /// @notice Creates a buffered note structured product by buying long calls and long puts, and selling short puts
    /// @dev uses opyn's options vaults to mint oTokens
    function _createBufferedNote() internal {
        // require that this address has been set as an operator for msg.sender
        require(controller.isOperator(counterparty, address(this)), "!operator");

        // Create a long call vault which is owned by a desk, oTokens are owned by this contract.
        longCallVaultID = _createOptionsVault(
            counterparty, // vault owner
            longCallOtoken,
            wethCallCollateral / 1e10, // oTokens only have 8 decimals
            wrappedNative,
            wethCallCollateral,
            address(this), // receiver of oTokens
            IController.ActionType.DepositCollateral // deposit WETH into oToken vault
        );

        // Create a long put vault which is owned by a desk, oTokens are owned by this contract.
        _createOptionsVault(
            counterparty, // vault owner
            longPutOtoken,
            usdcPutCollateral * 1e10 / IOtoken(longPutOtoken).strikePrice(), // oTokens only have 8 decimals
            usdc,
            usdcPutCollateral,
            address(this), // receiver of oTokens
            IController.ActionType.DepositCollateral // deposit USDC into oToken vault
        );

        // Create a short put vault which is owned by this contract, oTokens are owned by the desk.
        // LongPutOtokens are used as collateral for this vault, not the underlying tokens.
        shortPutVaultID = _createOptionsVault(
            address(this), // vault owner
            shortPutOtoken,
            IOtoken(longPutOtoken).balanceOf(address(this)), // amount of new oTokens to mint
            longPutOtoken, // collateral to mint oTokens are oTokens for this vault
            IOtoken(longPutOtoken).balanceOf(address(this)), // amount of new oTokens to deposit
            counterparty, // receiver of oTokens
            IController.ActionType.DepositLongOption // deposit longPutOtoken into oToken vault
        );
    }

    /// @notice gets an oToken address. If the token contract does not already exist, it is created
    /// @param _underlying the underlying asset that the derivative tracks
    /// @param _strikeAsset the asset that the strike price is calculated with
    /// @param _collateralAsset the asset used to collateralize the oToken
    /// @param _strikePrice the strike price of the option
    /// @param _expiry the expiry timestamp of the option
    /// @param _isPut whether the option is a put or a call
    function _getOtoken(
        address _underlying,
        address _strikeAsset,
        address _collateralAsset,
        uint256 _strikePrice,
        uint256 _expiry,
        bool _isPut
    ) internal returns (address) {

        // Attempt to get oToken from the factory
        address otokenFromFactory =
            oTokenFactory.getOtoken(
                _underlying,
                _strikeAsset,
                _collateralAsset,
                _strikePrice,
                _expiry,
                _isPut
            );

        // return oToken if it exists
        if (otokenFromFactory != address(0)) {
            return otokenFromFactory;
        }

        // create the oToken
        address createdOtoken =
            oTokenFactory.createOtoken(
                _underlying,
                _strikeAsset,
                _collateralAsset,
                _strikePrice,
                _expiry,
                _isPut
            );

        require(createdOtoken != address(0), "!otoken");

        // return the oToken
        return createdOtoken;
    }

    /// @notice Creates an options vault and mints oTokens to the relevant party
    /// @param _owner the owner of the options vault
    /// @param _oToken oToken to be minted by the vault
    /// @param _mintAmount amount of oToken that the vault should mint
    /// @param _collateral token used as collateral for the vault
    /// @param _collateralAmount amount of collateral to be deposited
    /// @param _oTokenReceiver the address that will receive the minted oTokens
    /// @param _depositAction the Gamma Controller action type (either DepositCollateral or DepositLongOption)
    function _createOptionsVault(
        address _owner,
        address _oToken,
        uint256 _mintAmount,
        address _collateral,
        uint256 _collateralAmount,
        address _oTokenReceiver,
        IController.ActionType _depositAction
    ) internal returns (uint256 newVaultID) {
      
        // set approvals for the margin pool
        _collateral.safeApprove(marginPool, _collateralAmount);

        // get the next vault ID
        newVaultID = controller.getAccountVaultCounter(_owner) + 1;

        // list of actions to be executed by the gamma controller
        IController.ActionArgs[] memory actions = new IController.ActionArgs[](3);

        // create an options vault
        actions[0] = IController.ActionArgs({
            actionType: IController.ActionType.OpenVault,
            owner: _owner,
            secondAddress: address(0),
            asset: address(0),
            vaultId: newVaultID,
            amount: 0,
            index: 0,
            data: ""
        });

        // deposit collateral or oTokens into the vault
        actions[1] = IController.ActionArgs({
            actionType: _depositAction,
            owner: _owner,
            secondAddress: address(this), // address that is depositing the collateral
            asset: _collateral,
            vaultId: newVaultID,
            amount: _collateralAmount,
            index: 0,
            data: ""
        });

        // mint oTokens directly to the oToken receiver, settle price later on
        actions[2] = IController.ActionArgs({
            actionType: IController.ActionType.MintShortOption,
            owner: _owner,
            secondAddress: _oTokenReceiver, // Destination address that receives the oTokens
            asset: _oToken, // oToken address to be minted
            vaultId: newVaultID,
            amount: _mintAmount,
            index: 0,
            data: ""
        });

        // execute actions
        controller.operate(actions);
    }

    /// @notice redeems oTokens from a vault
    /// @param _oToken address of the oToken
    /// @param _owner owner of the vault
    /// @param _id ID of the vault
    function _redeemOtokens (
        address _oToken,
        address _owner,
        uint256 _id
    ) internal {

        // determine oToken balance of strategy
        uint256 oTokenAmount = _oToken.getBalanceOf(address(this));

        // set approvals for the margin pool
        _oToken.safeApprove(marginPool, oTokenAmount);

        // list of actions to be executed by the gamma controller
        IController.ActionArgs[] memory actions = new IController.ActionArgs[](1);

        // create a desk-owned vault for buying calls
        actions[0] = IController.ActionArgs({
            actionType: IController.ActionType.Redeem,
            owner: _owner,
            secondAddress: address(this), // address to redeem tokens to 
            asset: _oToken,
            vaultId: _id,
            amount: oTokenAmount,
            index: 0,
            data: ""
        });

        // execute actions
        controller.operate(actions);
    }
    
    /// @notice settles a vault
    /// @param _receiver recipient of the vault's collateral
    /// @param _owner owner of the vault
    /// @param _id ID of the vault
    function _settleVault(
        address _receiver, 
        address _owner, 
        uint256 _id
    ) internal {

        // list of actions to be executed by the gamma controller
        IController.ActionArgs[] memory actions = new IController.ActionArgs[](1);

        // create a desk-owned vault for buying calls
        actions[0] = IController.ActionArgs({
            actionType: IController.ActionType.SettleVault,
            owner: _owner,
            secondAddress: _receiver, // address to send the collateral to 
            asset: address(0),
            vaultId: _id,
            amount: 0,
            index: 0,
            data: ""
        });

        // execute actions
        controller.operate(actions);
    }

    /// @notice Gives allowances to contracts
    function _giveAllowances() internal {
        asset.safeApprove(address(swapRouter), type(uint256).max);
    }

    /**
    * @notice Gets the next options expiry timestamp
    * @param _timestamp is the expiry timestamp of the current option
    * Reference: https://codereview.stackexchange.com/a/33532
    * Examples:
    * getNextFriday(week 1 thursday) -> week 1 friday
    * getNextFriday(week 1 friday) -> week 2 friday
    * getNextFriday(week 1 saturday) -> week 2 friday
    */
    function _getNextFriday(uint256 _timestamp) internal pure returns (uint256) {
        // dayOfWeek = 0 (sunday) - 6 (saturday)
        uint256 dayOfWeek = ((_timestamp / 1 days) + 4) % 7;
        uint256 nextFriday = _timestamp + ((7 + 5 - dayOfWeek) % 7) * 1 days;
        uint256 friday8am = nextFriday - (nextFriday % (24 hours)) + (8 hours);

        // If the passed timestamp is day=Friday hour>8am, we simply increment it by a week to next Friday
        if (_timestamp >= friday8am) {
            friday8am += 7 days;
        }

        return friday8am;
    }
}