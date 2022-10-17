// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/Ribbon/IRibbonVault.sol";
import "src/interfaces/vault/ISwapRouter.sol";

import "src/libraries/SafeERC20.sol";
import "src/libraries/Wrapper.sol";
import "src/libraries/BytesLib.sol";

import "src/vault/strategies/template/PeriodicStrategy.sol";

contract ShortStrangleStrategy is PeriodicStrategy {
    using SafeERC20 for address;
    using Wrapper for address;
    using BytesLib for bytes;

    /************************************************
     *  Storage
     ***********************************************/

    /// @notice the put-selling ribbon vault 
    IRibbonVault public putSellingVault;

    /// @notice the call-selling ribbon vault
    IRibbonVault public callSellingVault;   

    /// @notice router for swapping tokens
    ISwapRouter public swapRouter;

    /// @notice address for the USDC token
    address public usdc;

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
    //  _usdc (address): the address of the USDC token
    //  _putSellingVault (address): the address of the Ribbon put-selling vault
    //  _callSellingVault (address): the address of the Ribbon call-selling vault
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
        usdc = _params.toAddress(0x48);
        putSellingVault = IRibbonVault(_params.toAddress(0x5C));
        callSellingVault = IRibbonVault(_params.toAddress(0x70));
        swapRouter = ISwapRouter(_params.toAddress(0x84));

        strategyState.round = 1;

        // set up approvals
        _giveAllowances();

        return true;
    }

    /************************************************
     *  DEPOSIT & WITHDRAWALS
     ***********************************************/

    /// @notice Initiates a redemption for underlying assets which executes when the round completes
    /// @param shares Number of shares to redeem
    /// @param to address to initiate redemption on behalf of
    function initiateRedeem(uint256 shares, address to) public override onlyBeaker returns (uint256) {
        require(shares > 0, "!shares");
        
        // get total underlying vault shares
        uint256 putShares = putSellingVault.shares(address(this));
        uint256 callShares = callSellingVault.shares(address(this));

        uint256 proRataPuts = shares * putShares / beaker.getTotalSupply();
        uint256 proRataCalls = shares * callShares / beaker.getTotalSupply();

        // initiate withdrawal in ribbon vaults
        putSellingVault.initiateWithdraw(uint128(proRataPuts));
        callSellingVault.initiateWithdraw(uint128(proRataCalls));

        // initiate the redeem
        return super.initiateRedeem(shares, to);
    }

    /************************************************
     *  STRATEGY OPERATIONS
     ***********************************************/

    /// @notice Closes the existing position and sets up next position
    function commitAndClose() external override onlyBeaker {}

    /// @notice Rolls the strategy's funds into a new strategy position
    /// @return mintShares the number of shares to mint for this new round
    function rollToNextPosition() external override onlyBeaker returns (uint256) {

        uint256 mintShares = _rollToNextPosition(_totalAssets());
        
        // create the next position
        _createPosition();
        
        // return the number of BLP shares to mint
        return mintShares;
    }

    /// @notice Custom keeper function that withdraws funds from underlying vaults
    /// so they can be withdrawn by EOAs
    function maxCompleteWithdraw() external onlyBeaker {

        // complete withdraw on both vaults
        putSellingVault.completeWithdraw();
        callSellingVault.completeWithdraw();

        // swap any usdc to the underlying
        swapRouter.swap(usdc, asset, usdc.getBalanceOf(address(this)), address(this));

        // swap any native asset to the underlying
        uint256 nativeBalance = address(this).balance;
        if (asset == wrappedNative && nativeBalance > 0) {
            wrappedNative.wrap(nativeBalance);
        }
    }

    /************************************************
     *  INTERNAL FUNCTIONS
     ***********************************************/

    /// @notice Opens the next strategy position
    function _createPosition() internal {

        // calculate half of the funds waiting to be locked
        uint256 halfUnderlying = strategyState.lockedAssets / 2;

        if (strategyState.lockedAssets > 0) {
            // swap half to usdc
            swapRouter.swap(asset, usdc, halfUnderlying, address(this));

            // deposit usdc to put-selling vault
            uint256 usdcBalance = usdc.getBalanceOf(address(this));
            putSellingVault.deposit(usdcBalance);

            // deposit wrappedNative to call-selling vault
            callSellingVault.deposit(halfUnderlying);
        }
    }

    /// @notice determines the total assets under control by the strategy
    function _totalAssets() internal view returns (uint256) {
        // get balance of assets under control
        uint256 putSellingAssets = putSellingVault.accountVaultBalance(address(this));
        uint256 callSellingAssets = callSellingVault.accountVaultBalance(address(this));

        // get value of put-selling vault assets in underlying asset
        uint256 putSellingUnderlying = ISwapRouter(swapRouter).getExpectedReturn(usdc, asset, putSellingAssets);

        // return all assets under control of the strategy
        return putSellingUnderlying + callSellingAssets + asset.getBalanceOf(address(this));
    }

    /// @notice Gives allowances to contracts
    function _giveAllowances() internal {
        asset.safeApprove(address(swapRouter), type(uint256).max);
        usdc.safeApprove(address(swapRouter), type(uint256).max);

        asset.safeApprove(address(callSellingVault), type(uint256).max);
        usdc.safeApprove(address(putSellingVault), type(uint256).max);
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}