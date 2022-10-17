// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "openzeppelin-contracts/interfaces/IERC20.sol";

interface ILongShort {

    event Upgrade(uint256 version);
    event LongShortV1(address admin, address tokenFactory, address staker);

    event SystemStateUpdated(
        uint32 marketIndex,
        uint256 updateIndex,
        int256 underlyingAssetPrice,
        uint256 longValue,
        uint256 shortValue,
        uint256 longPrice,
        uint256 shortPrice
    );

    event SyntheticMarketCreated(
        uint32 marketIndex,
        address longTokenAddress,
        address shortTokenAddress,
        address paymentToken,
        int256 initialAssetPrice,
        string name,
        string symbol,
        address oracleAddress,
        address yieldManagerAddress
    );

    event NextPriceRedeem(
        uint32 marketIndex,
        bool isLong,
        uint256 synthRedeemed,
        address user,
        uint256 oracleUpdateIndex
    );

    event NextPriceSyntheticPositionShift(
        uint32 marketIndex,
        bool isShiftFromLong,
        uint256 synthShifted,
        address user,
        uint256 oracleUpdateIndex
    );

    event NextPriceDeposit(
        uint32 marketIndex,
        bool isLong,
        uint256 depositAdded,
        address user,
        uint256 oracleUpdateIndex
    );

    event NextPriceDepositAndStake(
        uint32 marketIndex,
        bool isLong,
        uint256 amountToStake,
        address user,
        uint256 oracleUpdateIndex
    );

    event OracleUpdated(uint32 marketIndex, address oldOracleAddress, address newOracleAddress);

    event NewMarketLaunchedAndSeeded(uint32 marketIndex, uint256 initialSeed, uint256 marketLeverage);

    event ExecuteNextPriceSettlementsUser(address user, uint32 marketIndex);

    event MarketFundingRateMultiplerChanged(uint32 marketIndex, uint256 fundingRateMultiplier_e18);

    function staker() external view returns (address);

    function updateMarketOracle(uint32 marketIndex, address _newOracleManager) external;

    function syntheticTokens(uint32, bool) external view returns (address);

    function assetPrice(uint32) external view returns (int256);

    function paymentTokens(uint32) external view returns (address);

    function marketLeverage_e18(uint32) external view returns(uint256);

    function oracleManagers(uint32) external view returns (address);

    function latestMarket() external view returns (uint32);

    function marketUpdateIndex(uint32) external view returns (uint256);

    function batched_amountPaymentToken_deposit(uint32, bool) external view returns (uint256);

    function batched_amountSyntheticToken_redeem(uint32, bool) external view returns (uint256);

    function batched_amountSyntheticToken_toShiftAwayFrom_marketSide(uint32, bool)
        external
        view
        returns (uint256);

    function get_syntheticToken_priceSnapshot(uint32, uint256)
        external
        view
        returns (uint256, uint256);

    function get_syntheticToken_priceSnapshot_side(
        uint32,
        bool,
        uint256
    ) external view returns (uint256);

    function marketSideValueInPaymentToken(uint32 marketIndex)
        external
        view
        returns (uint128 marketSideValueInPaymentTokenLong, uint128 marketSideValueInPaymentTokenShort);

    function setUserTradeTimer(
        address user,
        uint32 marketIndex,
        bool isLong
    ) external;

    function checkIfUserIsEligibleToTrade(
        address user,
        uint32 marketIndex,
        bool isLong
    ) external;

    function checkIfUserIsEligibleToSendSynth(
        address user,
        uint32 marketIndex,
        bool isLong
    ) external;

    function updateSystemState(uint32 marketIndex) external;

    function updateSystemStateMulti(uint32[] calldata marketIndex) external;

    function getUsersConfirmedButNotSettledSynthBalance(
        address user,
        uint32 marketIndex,
        bool isLong
    ) external view returns (uint256 confirmedButNotSettledBalance);

    function executeOutstandingNextPriceSettlementsUser(address user, uint32 marketIndex) external;

    function shiftPositionNextPrice(
        uint32 marketIndex,
        uint256 amountSyntheticTokensToShift,
        bool isShiftFromLong
    ) external;

    function shiftPositionFromLongNextPrice(uint32 marketIndex, uint256 amountSyntheticTokensToShift)
        external;

    function shiftPositionFromShortNextPrice(uint32 marketIndex, uint256 amountSyntheticTokensToShift)
        external;

    function getAmountSyntheticTokenToMintOnTargetSide(
        uint32 marketIndex,
        uint256 amountSyntheticTokenShiftedFromOneSide,
        bool isShiftFromLong,
        uint256 priceSnapshotIndex
    ) external view returns (uint256 amountSynthShiftedToOtherSide);

    function mintLongNextPrice(uint32 marketIndex, uint256 amount) external;

    function mintShortNextPrice(uint32 marketIndex, uint256 amount) external;

    function mintAndStakeNextPrice(
        uint32 marketIndex,
        uint256 amount,
        bool isLong
    ) external;

    function redeemLongNextPrice(uint32 marketIndex, uint256 amount) external;

    function redeemShortNextPrice(uint32 marketIndex, uint256 amount) external;
}

interface IStaker {

    event Upgrade(uint256 version);

    event StakerV1(
        address admin,
        address floatTreasury,
        address floatCapital,
        address floatToken,
        uint256 floatPercentage
    );

    event MarketAddedToStaker(
        uint32 marketIndex,
        uint256 exitFee_e18,
        uint256 period,
        uint256 multiplier,
        uint256 balanceIncentiveExponent,
        int256 balanceIncentiveEquilibriumOffset,
        uint256 safeExponentBitShifting
    );

    event AccumulativeIssuancePerStakedSynthSnapshotCreated(
        uint32 marketIndex,
        uint256 accumulativeFloatIssuanceSnapshotIndex,
        uint256 accumulativeLong,
        uint256 accumulativeShort
    );

    event StakeAdded(address user, address token, uint256 amount, uint256 lastMintIndex);

    event StakeWithdrawn(address user, address token, uint256 amount);

    event StakeWithdrawnWithFees(address user, address token, uint256 amount, uint256 amountFees);

    event FloatMinted(address user, uint32 marketIndex, uint256 amountFloatMinted);

    event MarketLaunchIncentiveParametersChanges(
        uint32 marketIndex,
        uint256 period,
        uint256 multiplier
    );

    event StakeWithdrawalFeeUpdated(uint32 marketIndex, uint256 stakeWithdralFee);

    event BalanceIncentiveParamsUpdated(
        uint32 marketIndex,
        uint256 balanceIncentiveExponent,
        int256 balanceIncentiveCurve_equilibriumOffset,
        uint256 safeExponentBitShifting
    );

    event FloatPercentageUpdated(uint256 floatPercentage);

    event NextPriceStakeShift(
        address user,
        uint32 marketIndex,
        uint256 amount,
        bool isShiftFromLong,
        uint256 userShiftIndex
    );

    function userAmountStaked(address, address) external view returns (uint256);

    function addNewStakingFund(
        uint32 marketIndex,
        address longTokenAddress,
        address shortTokenAddress,
        uint256 kInitialMultiplier,
        uint256 kPeriod,
        uint256 unstakeFee_e18,
        uint256 _balanceIncentiveCurve_exponent,
        int256 _balanceIncentiveCurve_equilibriumOffset
    ) external;

    function pushUpdatedMarketPricesToUpdateFloatIssuanceCalculations(
        uint32 marketIndex,
        uint256 marketUpdateIndex,
        uint256 longTokenPrice,
        uint256 shortTokenPrice,
        uint256 longValue,
        uint256 shortValue
    ) external;

    function stakeFromUser(address from, uint256 amount) external;

    function shiftTokens(
        uint256 amountSyntheticTokensToShift,
        uint32 marketIndex,
        bool isShiftFromLong
    ) external;

    function latestRewardIndex(uint32 marketIndex) external view returns (uint256);

    function safe_getUpdateTimestamp(uint32 marketIndex, uint256 latestUpdateIndex)
        external
        view
        returns (uint256);

    function mintAndStakeNextPrice(
        uint32 marketIndex,
        uint256 amount,
        bool isLong,
        address user
    ) external;
}

interface ISyntheticToken is IERC20 {
    function stake(uint256) external;

    function mint(address, uint256) external;

    function burn(uint256 amount) external;
}

interface IFloatToken is IERC20 {
    function mint(address to, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}

interface IOracleManager {
    function admin() external view returns (address);

    function updatePrice() external returns (int256);

    function getLatestPrice() external view returns (int256);
}