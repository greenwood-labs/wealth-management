// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/interfaces/IERC4626.sol";
import "src/interfaces/vault/IBeakerFactory.sol";
import "src/interfaces/vault/IReinvestStrategy.sol";
import "src/libraries/BytesLib.sol";
import "src/libraries/FixedPoint.sol";
import "src/libraries/SafeERC20.sol";
import "src/vault/base/Governed.sol";
import "src/vault/BeakerERC20.sol";
import "src/vault/BeakerStorage.sol";

contract BeakerVault is IERC4626, BeakerERC20, BeakerStorage, Governed {
    using BytesLib for bytes;
    using FixedPoint for uint256;
    using SafeERC20 for address;

    /// @notice address of the collateral token
    address public override asset;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _governance) Governed(_governance) {}

    /// @notice Initializes the beaker
    function initialize(bytes memory _params)
        external
        override
        initializer
        returns (bool)
    {
        factory = msg.sender;
        vaultId = uint16(IBeakerFactory(factory).numVaults());

        strategy = _params.toAddress(0);
        router = _params.toAddress(20);
        asset = _params.toAddress(20 * 2);
        cap = _params.toUint256(20 * 3);

        // initialize Beaker ERC20
        __ERC20_init(
            _params.toString((20 * 3) + 32),
            _params.toString((20 * 3) + (32 * 2)),
            asset.getDecimals()
        );

        // approve its own strategy to spend collateral assets
        asset.safeApprove(strategy, type(uint256).max);

        return true;
    }

    /// @notice Deposits the collateral asset to the contract and receives the lp tokens in return
    /// @param _assets the amount of collateral asset to deposit
    /// @param _recipient the address to receive lp tokens
    function deposit(uint256 _assets, address _recipient)
        external
        override
        returns (uint256 shares)
    {
        // receive the collateral asset from msg.sender if the msg.sender is not equal to the beaker router
        if (msg.sender != router)
            asset.safeTransferFrom(msg.sender, address(this), _assets);

        (shares, ) = _deposit();

        // mint lp tokens to the recipient
        _mint(_recipient, shares);

        emit Deposit(msg.sender, _recipient, _assets, shares);
    }

    /// @notice Deposits the collateral asset to the contract and receives the lp tokens in return
    /// @param _shares the desired amount of lp tokens to receive
    /// @param _recipient the address to receive the lp tokens
    function mint(uint256 _shares, address _recipient)
        external
        override
        returns (uint256 assets)
    {
        require(_shares != 0, "!0");

        // convert the value from lp shares to collateral asset
        assets = previewMint(_shares);

        // receive the collateral asset from msg.sender
        asset.safeTransferFrom(msg.sender, address(this), assets);

        (uint256 shares, ) = _deposit();

        // mint lp tokens to the recipient
        _mint(_recipient, shares);

        emit Deposit(msg.sender, _recipient, assets, _shares);
    }

    /// @notice Redeems the lp tokens to receive the collateral asset back
    /// @param _shares the amount of lp tokens to redeem
    /// @param _recipient the address to receive the collateral asset
    /// @param _owner the owner of lp tokens to be burned
    function redeem(
        uint256 _shares,
        address _recipient,
        address _owner
    ) external override returns (uint256 assets) {
        // convert the value from collateral assets to lp shares
        require((assets = previewRedeem(_shares)) != 0, "zero assets");

        // reduce the allowance if the msg.sender is not the owner of lp tokens
        if (msg.sender != _owner) {
            uint256 allowed = allowance[_owner][msg.sender];

            if (allowed != type(uint256).max)
                allowance[_owner][msg.sender] = allowed - _shares;
        }

        // withdraw funds from its own strategy
        _withdraw(assets);

        // burn the owner's lp shares
        _burn(_owner, _shares);

        // transfer the collateral asset to the recipient
        asset.safeTransfer(_recipient, assets);

        emit Withdraw(msg.sender, _recipient, _owner, assets, _shares);
    }

    /// @notice Redeems the lp tokens to receive the collateral asset back
    /// @param _assets the desired amount of collateral asset to withdraw
    /// @param _recipient the address to receive the collateral asset
    /// @param _owner the owner of lp tokens to be burned
    function withdraw(
        uint256 _assets,
        address _recipient,
        address _owner
    ) external override returns (uint256 shares) {
        require(_assets != 0, "!0");

        // convert the value from collateral assets to lp shares
        shares = previewWithdraw(_assets);

        // reduce the allowance if the msg.sender is not the owner of lp tokens
        if (msg.sender != _owner) {
            uint256 allowed = allowance[_owner][msg.sender];

            if (allowed != type(uint256).max)
                allowance[_owner][msg.sender] = allowed - shares;
        }

        // withdraw funds from its own strategy
        _withdraw(_assets);

        // burn the owner's lp shares
        _burn(_owner, shares);

        // transfer the collateral asset to the recipient
        asset.safeTransfer(_recipient, _assets);

        emit Withdraw(msg.sender, _recipient, _owner, _assets, shares);
    }

    /// @notice Deposits the collateral asset to its own strategy contract for the amount of its current holding
    function _deposit() internal returns (uint256 shares, uint256 assets) {
        // read its current balance for the collateral asset
        assets = asset.getBalanceOf(address(this));

        // convert the value from collateral assets to lp shares
        require((shares = previewDeposit(assets)) != 0, "zero shares");

        // deposit the collateral asset to its own strategy
        IReinvestStrategy(strategy).deposit(assets);
    }

    /// @notice Withdraws the collateral asset from its own strategy for a given amount
    function _withdraw(uint256 _amount) internal {
        IReinvestStrategy(strategy).withdraw(_amount);
    }

    /// @notice Returns the converted value from collateral assets to lp shares for a given amount
    /// @param _assets the amount to convert
    function convertToShares(uint256 _assets)
        public
        view
        override
        returns (uint256 shares)
    {
        uint256 _totalSupply = totalSupply;

        return
            _totalSupply == 0
                ? _assets
                : _assets.mulDivDown(_totalSupply, totalAssets());
    }

    /// @notice Returns the converted value from lp shares to collateral assets for a given amount
    /// @param _shares the amount to convert
    function convertToAssets(uint256 _shares)
        public
        view
        override
        returns (uint256 assets)
    {
        uint256 _totalSupply = totalSupply;

        return
            _totalSupply == 0
                ? _shares
                : _shares.mulDivDown(totalAssets(), _totalSupply);
    }

    /// @notice Returns the max value of available deposits
    function maxDeposit(address) public view override returns (uint256) {
        return cap;
    }

    /// @notice Returns the max value of available mints
    function maxMint(address) public view override returns (uint256) {
        return cap == type(uint256).max ? cap : convertToShares(cap);
    }

    /// @notice Returns the max value of available redeems
    function maxRedeem(address _account)
        public
        view
        override
        returns (uint256)
    {
        return balanceOf[_account];
    }

    /// @notice Returns the max value of available withdraws
    function maxWithdraw(address _account)
        public
        view
        override
        returns (uint256)
    {
        return convertToAssets(balanceOf[_account]);
    }

    /// @notice Returns the converted value from collateral assets to lp shares on deposit
    /// @param _assets the amount to convert
    function previewDeposit(uint256 _assets)
        public
        view
        override
        returns (uint256 shares)
    {
        require(maxDeposit(address(0)) >= _assets, "exceeds max deposit");

        return convertToShares(_assets);
    }

    /// @notice Returns the converted value from lp shares to collateral assets on mint
    /// @param _shares the amount to convert
    function previewMint(uint256 _shares)
        public
        view
        override
        returns (uint256)
    {
        require(maxMint(address(0)) >= _shares, "exceeds max mint");

        uint256 _totalSupply = totalSupply;

        return
            _totalSupply == 0
                ? _shares
                : _shares.mulDivDown(totalAssets(), _totalSupply);
    }

    /// @notice Returns the converted value from lp shares to collateral assets on redeem
    /// @param _shares the amount to convert
    function previewRedeem(uint256 _shares)
        public
        view
        override
        returns (uint256 assets)
    {
        return convertToAssets(_shares);
    }

    /// @notice Returns the converted value from collateral assets to lp shares on withdraw
    /// @param _assets the amount to convert
    function previewWithdraw(uint256 _assets)
        public
        view
        override
        returns (uint256)
    {
        uint256 _totalSupply = totalSupply;

        return
            _totalSupply == 0
                ? _assets
                : _assets.mulDivDown(_totalSupply, totalAssets());
    }

    /// @notice Returns the total amount of deposits to its strategy contract
    function totalAssets() public view override returns (uint256) {
        return IReinvestStrategy(strategy).totalDeposits();
    }

    /// @notice Sets a new capacity for deposits
    /// @param _newCap the new capacity to set
    function setCap(uint256 _newCap) external onlyGovernance {
        cap = _newCap;
    }

    /// @notice Sets a new beaker router contract
    /// @param _newRouter the new router to set
    function setRouter(address _newRouter) external onlyGovernance {
        router = _newRouter;
    }

    /// @notice Sets a new strategy contract
    /// @param _newStrategy the new strategy to set
    function setStrategy(address _newStrategy) external onlyGovernance {
        require(
            _newStrategy != address(0) && strategy != _newStrategy,
            "!newStrategy"
        );

        IReinvestStrategy oldStrategy = IReinvestStrategy(strategy);

        uint256 totalDepositsPrior = oldStrategy.totalDeposits();

        oldStrategy.migrate(_newStrategy);

        require(
            oldStrategy.totalDeposits() == 0 &&
                IReinvestStrategy(_newStrategy).totalDeposits() >=
                totalDepositsPrior,
            "migration failed"
        );

        strategy = _newStrategy;
    }
}
