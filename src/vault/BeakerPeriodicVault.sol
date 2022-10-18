// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/utils/Strings.sol";

import "src/interfaces/vault/IBeakerFactory.sol";
import "src/interfaces/vault/IBeakerPeriodicVault.sol";
import "src/interfaces/vault/IPeriodicStrategy.sol";

import "src/vault/base/ReentrancyGuard.sol";
import "src/vault/base/Governed.sol";
import "src/vault/BeakerERC20.sol";
import "src/vault/BeakerStorage.sol";

import "src/libraries/Bytes32Strings.sol";
import "src/libraries/BytesLib.sol";
import "src/libraries/SafeERC20.sol";
import "src/libraries/Wrapper.sol";

contract BeakerPeriodicVault is 
    Governed,
    ReentrancyGuard,
    BeakerStorage, 
    IBeakerPeriodicVault,
    BeakerERC20
{
    using SafeERC20 for address;
    using Wrapper for address;
    using BytesLib for bytes;

    /************************************************
     *  STORAGE
     ***********************************************/

	/// @notice asset managed by the strategy
    address public asset;

    /// @notice Role in charge of rolling beaker operations
    /// Does not have access to critical beaker functions
    address public override keeper;

    /// @notice utility functions callable only by the keeper
    mapping(uint256 => bytes) public keeperCalls;

    /************************************************
     *  MODIFIERS
     ***********************************************/

    /// @notice throws if called by an account that is not keeper
    modifier onlyKeeper() {
        require(msg.sender == keeper, "!keeper");
        _;
    }

    /************************************************
     *  CONSTRUCTOR & INITIALIZATION
     ***********************************************/

    // solhint-disable-next-line no-empty-blocks
    constructor(address _governance) Governed(_governance) {}

    /// @notice Initializes the contract with storage variables
    /// @param _params parameters to initialize the beaker
    //  _strategy (address): strategy address of the beaker
    //  _keeper (address): keeper of the beaker
    //  _router (address): the swap router address
    //  _capacity (uint256): max capacity of the underlying asset for the beaker
    //  _asset (address): the asset handled by the beaker
    //  _tokenName (bytes32): name of the BLP token
    //  _keeperCalls (bytes[] memory): utility functions callable only by the keeper
    function initialize(bytes memory _params) 
        external 
        override 
        initializer
        returns (bool) 
    {
        strategy = _params.toAddress(0x00);
        keeper = _params.toAddress(0x14);
        router = _params.toAddress(0x28);
        cap = _params.toUint256(0x3C);
        asset = _params.toAddress(0x5C);

        factory = msg.sender;
        vaultId = uint16(IBeakerFactory(factory).numVaults());

        // approve the strategy to pull the underlying asset from the beaker when needed
        asset.safeApprove(strategy, type(uint256).max);

        // Initialize ERC20 token
        __ERC20_init(
            Bytes32Strings.bytes32ToString(_params.toBytes32(0x70)),
            string(abi.encodePacked("BLP-", Strings.toString(vaultId))),
            18
        );

        // check if there are keeper calls
        if (_params.length > 0x90) {
            
            // initialize keeper calls
            uint256 pointer = 0x90;
            for (uint256 i; pointer < _params.length; ) {
                keeperCalls[i] = _params.slice(pointer, 0x4);

                unchecked { i++; }
                pointer = pointer + (i * 0x4);
            } 
        }

        return true;
    }

    /************************************************
     *  SETTERS
     ***********************************************/

    /// @notice sets a new keeper for this beaker
    /// @param _newKeeper the new keeper to set
    function setKeeper(address _newKeeper) external onlyGovernance {
        require(_newKeeper != address(0), "!newKeeper");

        keeper = _newKeeper;
    }

    /// @notice sets a new capacity for deposits
    /// @param _newCap the new capacity to set
    function setCap(uint256 _newCap) external onlyGovernance {
        require(_newCap > 0, "!_newCapacity");

        cap = _newCap;
    }

    /// @notice sets a new router for the beaker
    /// @param _newRouter the new capacity to set
    function setRouter(address _newRouter) external onlyGovernance {
        router = _newRouter;
    }

    /// @notice sets a new strategy for the beaker
    /// @param _newStrategy the new capacity to set
    function setStrategy(address _newStrategy) external onlyGovernance {
        strategy = _newStrategy;
    }

    /************************************************
     *  GETTERS
     ***********************************************/

    /// @notice gets the total assets stored by the beaker
    /// @return totalAssets assets stored in the beaker and the strategy
    function totalAssets() public view override returns (uint256) {
        uint256 beakerBalance = asset.getBalanceOf(address(this));

        return IPeriodicStrategy(strategy).totalBalance() + beakerBalance;
    }

    /// @notice Returns the total number of shares entitled to an account
    /// @param account account that is entitled to the shares
    function accountShares(address account) public view override returns (uint256) {
        return IPeriodicStrategy(strategy).accountShares(account);
    }

    /// @notice Getter for returning the account's share balance split between account and vault holdings
    /// @param account is the account to lookup share balance for
    /// @return heldByAccount is the shares held by account
    /// @return heldByVault is the shares held on the vault (unredeemedShares)
    function shareBalances(address account)
        public
        view
        override 
        returns (uint256 heldByAccount, uint256 heldByVault)
    {
        return IPeriodicStrategy(strategy).shareBalances(account);
    }

    /************************************************
     *  DEPOSIT & WITHDRAWALS
     ***********************************************/

    /// @notice Deposits the asset from msg.sender
    /// @param assets the amount of asset to deposit
    function deposit(uint256 assets) external override unlocked {
        // router will have already sent funds, no need to transfer from
        if (msg.sender != router)
            asset.safeTransferFrom(msg.sender, address(this), assets);

        _deposit(assets, msg.sender);
    }

    /// @notice Initiates a redemption for underlying assets which executes when the round completes
    /// @param shares Number of shares to redeem
    function initiateRedeem(uint256 shares) external override unlocked {
        uint256 outstandingSharesToRequest = _initiateRedeem(shares, msg.sender);

        // pull shares from msg.sender if there aren't enough unclaimed shares held in the vault
        if (outstandingSharesToRequest > 0)
            address(this).safeTransferFrom(msg.sender, address(this), outstandingSharesToRequest);
        
    }

    /// @notice Completes a scheduled redemption from a past round
    function redeem() external override unlocked { 
        (uint256 assetAmount, uint256 sharesToBurn) = _redeem(msg.sender);

        _burn(address(this), sharesToBurn);
        
        asset.safeTransfer(msg.sender, assetAmount);
    }

    /// @notice Withdraws assets in the beaker that were deposited in the current round
    /// @param assets amount of assets to withdraw
    function withdraw(uint256 assets) external override unlocked {
        _withdraw(assets, msg.sender);

        asset.safeTransfer(msg.sender, assets);
    }

    /// @notice claims shares owed to an account
    /// @param shares Number of shares to claim
    function claimShares(uint256 shares) external override unlocked {
        uint256 numShares = _claimShares(shares, msg.sender);

        address(this).safeTransfer(msg.sender, numShares);
    }

    function _deposit(uint256 _amount, address _to) internal {
        IPeriodicStrategy(strategy).deposit(_amount, _to);
    }

    function _initiateRedeem(uint256 _shares, address _to) internal returns (uint256) {
        return IPeriodicStrategy(strategy).initiateRedeem(_shares, _to);
    }

    function _redeem(address _to) internal returns (uint256, uint256) {
        return IPeriodicStrategy(strategy).redeem(_to);
    }

    function _withdraw(uint256 _amount, address _to) internal {
        return IPeriodicStrategy(strategy).withdraw(_amount, _to);
    }

    function _claimShares(uint256 _shares, address _to) internal returns (uint256) {
        return IPeriodicStrategy(strategy).claimShares(_shares, _to);
    }

    /************************************************
     *  VAULT OPERATIONS
     ***********************************************/

    /// @notice Closes the existing position and sets up next position
    function commitAndClose() external override onlyKeeper unlocked {
        IPeriodicStrategy(strategy).commitAndClose();
    }

    /// @notice Rolls the beaker's funds into a new strategy position
    function rollToNextPosition() external override onlyKeeper unlocked {
        uint256 sharesToMint = IPeriodicStrategy(strategy).rollToNextPosition();

        _mint(address(this), sharesToMint);
    }

    /// @notice allows the keeper to make calls to arbitrary functions in the strategy contract
    /// @param callId the ID of the strategy call
    function keeperCall(uint256 callId) external payable onlyKeeper {
        (bool success, ) = payable(strategy).call{value: msg.value}(keeperCalls[callId]);
        require(success, "!success");
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}