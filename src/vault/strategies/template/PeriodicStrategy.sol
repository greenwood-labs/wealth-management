// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/IPeriodicStrategy.sol";
import "src/interfaces/vault/IBeakerPeriodicVault.sol";
import "src/interfaces/vault/IBeakerStorage.sol";

import "src/libraries/Periodic.sol";
import "src/libraries/ShareMath.sol";
import "src/libraries/SafeERC20.sol";
import "src/libraries/Wrapper.sol";

import "src/vault/base/Governed.sol";
import "src/vault/base/Initializable.sol";

abstract contract PeriodicStrategy is IPeriodicStrategy, Initializable, Governed {
    using SafeERC20 for address;
    using Wrapper for address;

    /************************************************
     *  STORAGE
     ***********************************************/

    /// @notice the beaker address for the current strategy
    address public override beaker;

    /// @notice the underlying asset for the strategy
    address public override asset;

    /// @notice period between each round
    uint256 public override period;

    /// @notice the strategy's lifecycle state
    Periodic.StrategyState public override strategyState;

    /// @notice Stores the user's pending deposit for the round
    /// These are shares that have been awarded but have not yet been 
    /// minted to the depositor
    mapping(address => Periodic.Deposit) public override deposits;

    /// @notice Stores pending user redemptions
    mapping(address => Periodic.Redemption) public override redemptions;

    /// @notice After each round closes, pricePerShare value of a BLP token is stored
    /// Used to determine the number of BLP shares to be returned to a user
    /// with their Deposit.depositAmount
    mapping(uint256 => uint256) public override roundPricePerShare;

    /************************************************
     *  IMMUTABLES & CONSTANTS
     ***********************************************/

    /// @notice wrapped native chain token
    address public override immutable wrappedNative;

    /************************************************
     *  CONSTRUCTOR & INITIALIZATION
     ***********************************************/

    /// @notice constructs the strategy
    /// @param _wnative the wrapped native token of the chain
    /// @param _governance governance address to manage strategy
    constructor(
        address _wnative,
        address _governance
    ) Governed(_governance) {
        require(_wnative != address(0), "!_native");

        wrappedNative = _wnative;
    }

    /************************************************
     *  MODIFIERS
     ***********************************************/

     /// @notice modifier to only the beaker contract to make a call
    modifier onlyBeaker() {
        require(msg.sender == beaker, "!beaker");
        _;
    }

    /************************************************
     *  SETTERS
     ***********************************************/

     /// @notice migrates funds from this strategy to another one
     /// @param _newStrategy the new strategy to migrate funds to
    function migrate(address _newStrategy) external override onlyGovernance {

        uint256 amount = asset.getBalanceOf(address(this));

        asset.safeTransfer(_newStrategy, amount);
    }

    /// @notice sets the strategy to a new beaker address
    /// @param _beaker the new beaker to use
    function setBeaker(address _beaker) external override onlyGovernance {
        require(_beaker != address(0), "zero address");

        beaker = _beaker;
    }

    /************************************************
     *  GETTERS
     ***********************************************/

    /// @notice Returns the strategy's total balance, including assets locked into a strategy
    /// @return total balance of the strategy
    function totalBalance() public view override returns (uint256) {
        return strategyState.lockedAssets + asset.getBalanceOf(address(this));
    }

    /// @notice Returns the total number of shares entitled to an account
    /// @param account account that is entitled to the shares
    function accountShares(address account) public view override returns (uint256) {
        (uint256 heldByAccount, uint256 heldByVault) = shareBalances(account);
        return heldByAccount + heldByVault;
    }

   
    /// @notice Getter for returning the account's share balance split between account and vault holdings
    /// @param account is the account to lookup share balance for
    /// @return heldByAccount is the shares held by account
    /// @return heldByVault is the shares held on the vault (unclaimedShares)
    function shareBalances(address account)
        public
        view
        override 
        returns (uint256 heldByAccount, uint256 heldByVault)
    {
        Periodic.Deposit memory userDeposit = deposits[account];

        uint256 unclaimedShares =
            ShareMath.getSharesFromDeposit(
                userDeposit,
                strategyState.round,
                roundPricePerShare[userDeposit.round],
                beaker.getDecimals()
            );

        return (beaker.getBalanceOf(account), unclaimedShares);
    }

    /************************************************
     *  DEPOSIT & WITHDRAWALS
     ***********************************************/

    /// @notice Deposits the asset from msg.sender
    /// @param assets the amount of asset to deposit
    /// @param to address to deposit on behalf of
    function deposit(uint256 assets, address to) external override onlyBeaker {
        require(assets > 0, "!amount");

        // WARNING: potentially not safe for ERC777 tokens, even with reentrancy guard
        _deposit(assets, to);

        // transfer tokens to the strategy
        asset.safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @notice mints BLP shares to the specified address
    /// @param _amount the amount of the underlying asset to deposit
    /// @param _to the address to mint BLP shares
    function _deposit(uint256 _amount, address _to) private {

        uint256 currentRound = strategyState.round;
        uint256 totalWithDepositedAmount = totalBalance() + _amount;

        // ensure deposit amount is correct
        require(totalWithDepositedAmount <= IBeakerStorage(beaker).cap(), "Exceeded capacity");

        // Get the deposit of the user
        Periodic.Deposit memory userDeposit = deposits[_to];

        // Process any leftover pending deposits from the previous rounds
        uint256 unclaimedShares = ShareMath.getSharesFromDeposit(
            userDeposit,
            currentRound, 
            roundPricePerShare[userDeposit.round], 
            beaker.getDecimals()
        );

        // If there's a pending deposit from the current round, then add the 
        // current deposit amount to the pending deposit
        uint256 depositAmount = currentRound == userDeposit.round
            ? userDeposit.amount + _amount
            : _amount;

        // Create a new deposit with the updated values
        deposits[_to] = Periodic.Deposit({
            round: currentRound,
            amount: depositAmount,
            unclaimedShares: unclaimedShares
        });

        // Update the amount of assets awaiting deposit
        strategyState.totalPendingDeposits += _amount;
    }

    /// @notice Initiates a redemption for underlying assets which executes when the round completes
    /// @param shares Number of shares to withdraw
    /// @param to address to initiate withdraw on behalf of
    function initiateRedeem(uint256 shares, address to) public virtual override onlyBeaker returns (uint256) {
        require(shares > 0, "!shares");

        // the amount of shares to be transferred from the EOA, after accounting for all
        // unclaimed shares that were never separately claimed by the EOA
        uint256 sharesToRequest = shares;

        // perform a max claim before initiating the redemption
        if (deposits[to].amount > 0 || deposits[to].unclaimedShares > 0) {
            sharesToRequest -= _claimShares(0, to, true);
        }

        uint256 currentRound = strategyState.round;
        Periodic.Redemption storage redemption = redemptions[to];

        // Is the redemption in the same round as a previous redemption
        bool sameRoundRedemption = currentRound == redemption.round;

        uint256 existingRedemptionShares = redemption.shares;

        // If another redemption was initiated in the same round, then stack the shares to be redeemed
        // otherwise, ensure no pending completed redemption exists and update the redemption
        uint256 redemptionShares;
        if (sameRoundRedemption) {
            redemptionShares = existingRedemptionShares + shares;
        } else {
            require(existingRedemptionShares == 0, "Existing redemption must be completed");
            redemptionShares = shares;
            redemptions[to].round = currentRound;
        }

        // update the user's shares marked for redemption
        redemptions[to].shares = redemptionShares;

        // update the total shares queued for redemption
        strategyState.sharesQueuedForRedemption += shares;

        // return the number of outstanding external shares to request
        return sharesToRequest;
    }

    /// @notice Completes a scheduled withdrawal from a past round
    /// @param to address to complete withdraw on behalf of
    /// @return redeemAmount amount of asset that is redeemed
    /// @return sharesToBurn the number of shares to be burned
    function redeem(address to) public virtual override onlyBeaker returns (uint256 redeemAmount, uint256 sharesToBurn) { 
        // calculate the amount of asset to redeem
        (redeemAmount, sharesToBurn) = _redeem(to);

        // reduce the amount of unlocked assets awaiting redemption
        strategyState.assetsUnlockedForRedemption -= redeemAmount;
    }

    /// @notice completes a scheduled withdrawal from a past round
    /// @param _to address to complete withdraw on behalf of
    /// @return redeemAmount amount of asset that is withdrawn
    /// @return sharesToBurn the number of shares to be burned
    function _redeem(address _to) internal returns (uint256 redeemAmount, uint256 sharesToBurn) {
        Periodic.Redemption storage redemption = redemptions[_to];

        sharesToBurn = redemption.shares;
        uint256 redemptionRound = redemption.round;

        require(sharesToBurn > 0, "Withdrawal not initiated");
        require(redemptionRound < strategyState.round, "Round hasnt closed");

        // zero out the user's shares and update the total number of shares queued for redemption
        redemptions[_to].shares = 0;
        strategyState.sharesQueuedForRedemption -= sharesToBurn;

        // calculate amount of underlying asset to redeem
        redeemAmount = ShareMath.sharesToAssets(
            sharesToBurn, 
            roundPricePerShare[redemptionRound], 
            beaker.getDecimals()
        );

        require(redeemAmount > 0, "!withdrawAmount");

        // transfer assets to the beaker
        asset.safeTransfer(msg.sender, redeemAmount);
    }

    /// @notice Withdraws assets in the beaker that were deposited in the current round
    /// @param assets amount of assets to withdraw
    /// @param to address to withdraw instantly on behalf of
    function withdraw(uint256 assets, address to) public override onlyBeaker {
        Periodic.Deposit storage userDeposit = deposits[to];

        uint256 currentRound = strategyState.round;

        // ensure theres a balance to withdraw and that the deposit occurred in the same round
        // as this withdraw
        require(assets > 0, "!amount");
        require(userDeposit.round == currentRound, "Invalid round");
        require(userDeposit.amount >= assets, "Exceeded amount deposited");

        // reduce deposit and remove the amount from 
        // the pending funds that havent minted BLP tokens
        userDeposit.amount -= assets;
        strategyState.totalPendingDeposits -= assets;

        // transfer assets to the beaker
        asset.safeTransfer(msg.sender, assets);
    }

    /// @notice claims shares owed to an account
    /// @param shares Number of shares to claim
    /// @param to address to claim on behalf of
    /// @return numShares the number of shares being claimed
    function claimShares(uint256 shares, address to) external override onlyBeaker returns (uint256) {
        require(shares > 0, "!shares");

        // claim shares, do a max claim if specified
        uint256 numShares = shares == type(uint256).max
            ? _claimShares(0, to, true)
            : _claimShares(shares, to, false);

        return numShares;
    }

    /// @notice claims shares owed to an account
    /// @param _shares Number of shares to claim
    /// @param _isMax Whether the claim is a max claim
    /// @return numShares the number of shares being claimed
    function _claimShares(uint256 _shares, address _to, bool _isMax) internal returns (uint256) {
        Periodic.Deposit memory userDeposit = deposits[_to];

        // handles case where deposit.round is 0
        uint256 currentRound = strategyState.round;

        // get all unclaimed shares
        uint256 unclaimedShares = ShareMath.getSharesFromDeposit(
            userDeposit,
            currentRound,
            roundPricePerShare[userDeposit.round],
            beaker.getDecimals()
        );

        // calculate the number of shares to claim
        uint256 numShares = _isMax ? unclaimedShares : _shares;
        if (numShares == 0) return 0;

        require(numShares <= unclaimedShares, "Exceeds available shares");

        // When claiming shares on the current round, leave the amount field as-is so that
        // the current round's deposit can be withdrawn instantly if the claimed shares are returned.
        // If the round has past, then we can adjust the deposit amount to 0
        if (userDeposit.round < currentRound) {
            deposits[_to].amount = 0;
        }

        // subtract shares from the unclaimed shares
        deposits[_to].unclaimedShares = unclaimedShares - numShares;

        // return number of shares to claim
        return numShares;
    }

    /************************************************
     *  STRATEGY OPERATIONS
     ***********************************************/

    /// @notice initiates the next round
    /// @return sharesToMint the number of shares to mint for this new round
    function _rollToNextPosition(uint256 _assetsUnderControl) internal returns (uint256) {
        require(block.timestamp > strategyState.roundExpiration, "round in progress");

        // Calculate all values for the next rollover
        (
            uint256 lockedAssets,
            uint256 assetsUnlockedForRedemption,
            uint256 newPricePerShare,
            uint256 sharesToMint
        ) = Periodic.calculateRolloverValues(
            strategyState, 
            Periodic.RolloverParams(
                beaker.getDecimals(),
                _assetsUnderControl,
                beaker.getTotalSupply()
            ));

        // Finalize the price per share at the end of this round
        uint256 currentRound = strategyState.round;
        roundPricePerShare[currentRound] = newPricePerShare;

        // set the new round expiration timestamp
        strategyState.roundExpiration = block.timestamp + period;

        // Zero out total pending deposits
        strategyState.totalPendingDeposits = 0;

        // Increment the round
        strategyState.round = currentRound + 1;

        // set the current round's queued redemption amount to now
        // be the last round's queued redemption amount
        strategyState.assetsUnlockedForRedemption = assetsUnlockedForRedemption;

        // set the locked amount of underlying assets for the next round
        strategyState.lockedAssets = lockedAssets;
        
        // return number of new shares to mint
        return sharesToMint;
    }
}