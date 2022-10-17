// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/Float/IFloat.sol";
import "src/interfaces/vault/ISwapRouter.sol";

import "src/libraries/SafeERC20.sol";
import "src/libraries/BytesLib.sol";

import "src/vault/strategies/template/PeriodicStrategy.sol";

contract FloatStrategy is PeriodicStrategy {
    using SafeERC20 for address;
    using BytesLib for bytes;

    /************************************************
     *  Storage
     ***********************************************/

     /// @notice whether the strategy is for a long or short token position (1 or 0)
    uint8 public isLong;

    /// @notice market index ID of the underlying asset
    uint32 public marketIndex;

    /// @notice the receipt token after depositing into the protocol
    ISyntheticToken public synthToken;

    /// @notice float capital perpetual execution contract
    ILongShort public longShort;

    /// @notice router for swapping tokens
    ISwapRouter public swapRouter;

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
    //  _synthToken (address): the address of the synthetic token
    //  _longShort (address): the address of the Float long-short contract
    //  _swapRouter (address): the swap router address
    //  _marketIndex (uint256): the market index of the asset of the strategy
    //  _isLong (uint8): whether this is a long or short strategy, will be used as boolean
    function initialize(bytes memory _params)
        external
        override
        initializer
        returns (bool)
    {
        beaker = _params.toAddress(0x00);
        asset = _params.toAddress(0x14);
        period = _params.toUint256(0x28);

        synthToken = ISyntheticToken(_params.toAddress(0x48));
        longShort = ILongShort(_params.toAddress(0x5C));
        swapRouter = ISwapRouter(_params.toAddress(0x70));
        marketIndex = _params.toUint32(0x84);
        isLong = _params.toUint8(0x88);

        strategyState.round = 1;

        // set up approvals
        _giveAllowances();

        return true;
    }

    /************************************************
     *  STRATEGY OPERATIONS
     ***********************************************/

    /// @notice Closes the existing position and sets up next position
    function commitAndClose() external override onlyBeaker {
        // closes the current position
        _closePosition();
    }

    /// @notice Rolls the strategy's funds into a new strategy position
    /// @return mintShares the number of shares to mint for this new round
    function rollToNextPosition() external override onlyBeaker returns (uint256) {

        uint256 mintShares = _rollToNextPosition(asset.getBalanceOf(address(this)));
        
        // create the next position
        _createPosition();
        
        // return the number of shares to mint
        return mintShares;
    }

    /// @notice updates a market to use a new oracle price
    function updateNextPrice() external onlyBeaker {
        longShort.updateSystemState(marketIndex);
    }

    /// @notice after a market has been updated with a new oracle price, transfers any owed tokens
    /// to a user
    function executeNextPriceSettlements() external onlyBeaker {
        longShort.executeOutstandingNextPriceSettlementsUser(address(this), marketIndex);
    }
    /************************************************
     *  INTERNAL FUNCTIONS
     ***********************************************/

    /// @notice Opens the next strategy position
    function _createPosition() internal {

        // dont deposit into Float Capital unless new funds are 
        // queued for deposit
        if (strategyState.lockedAssets == 0) return;

        // mint synthetic tokens, to be claimed on next price update
        if (isLong == 1) {
            longShort.mintLongNextPrice(marketIndex, strategyState.lockedAssets);
        } else {
            longShort.mintShortNextPrice(marketIndex, strategyState.lockedAssets);
        }
    }

    /// @notice Closes the previous strategy position
    function _closePosition() internal {
        // balance of synthetic tokens
        uint256 synthTokenBalance = synthToken.balanceOf(address(this));

        // dont withdraw from Float Capital unless there is a positive synth token balance
        if (synthTokenBalance == 0) return;

        // redeem tokens, underlying assets to be claimed on next price update
        if (isLong == 1) {
            longShort.redeemLongNextPrice(marketIndex, synthTokenBalance);
        } else {
            longShort.redeemShortNextPrice(marketIndex, synthTokenBalance);
        }
        
    }

    /// @notice Gives allowances to contracts
    function _giveAllowances() internal {
        asset.safeApprove(address(swapRouter), type(uint256).max);
        asset.safeApprove(address(longShort), type(uint256).max);
    }
}