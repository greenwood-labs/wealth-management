// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "openzeppelin-contracts/interfaces/IERC20Metadata.sol";

interface ICurveLP is IERC20Metadata {
    function minter() external view returns (address);

    function mint(address to, uint256 value) external;

    function mint_relative(address to, uint256 frac) external;

    function burn_from(address to, uint256 value) external;
}

interface ICurvePool is IERC20Metadata {
    function coins(uint256 i) external view returns (address);

    function underlying_coins(uint256 i) external view returns (address);

    function balances(uint256 i) external view returns (uint256);

    function get_virtual_price() external view returns (uint256);

    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external payable;

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external payable;

    function calc_token_amount(uint256[2] memory amounts, bool isDeposit)
        external
        view
        returns (uint256);

    function calc_token_amount(uint256[3] memory amounts, bool isDeposit)
        external
        view
        returns (uint256);

    function calc_token_amount(uint256[4] memory amounts, bool isDeposit)
        external
        view
        returns (uint256);

    function calc_token_amount(uint256[5] memory amounts, bool isDeposit)
        external
        view
        returns (uint256);

    function calc_token_amount(
        address pool,
        uint256[4] memory amounts,
        bool isDeposit
    ) external view returns (uint256);

    function calc_withdraw_one_coin(uint256 amount, int128 i)
        external
        view
        returns (uint256);

    function calc_withdraw_one_coin(
        address pool,
        uint256 amount,
        int128 i
    ) external view returns (uint256);

    function add_liquidity(uint256[2] calldata amounts, uint256 minMint)
        external
        payable;

    function add_liquidity(uint256[3] calldata amounts, uint256 minMint)
        external
        payable;

    function add_liquidity(uint256[4] calldata amounts, uint256 minMint)
        external;

    function add_liquidity(uint256[5] calldata amounts, uint256 minMint)
        external;

    function add_liquidity(
        uint256[2] memory amounts,
        uint256 minMint,
        bool useUnderlying
    ) external payable;

    function add_liquidity(
        uint256[3] memory amounts,
        uint256 minMint,
        bool useUnderlying
    ) external payable;

    function add_liquidity(
        uint256[4] memory amounts,
        uint256 minMint,
        bool useUnderlying
    ) external;

    function add_liquidity(
        uint256[5] memory amounts,
        uint256 minMint,
        bool useUnderlying
    ) external;

    function add_liquidity(
        address pool,
        uint256[4] memory amounts,
        uint256 minMint
    ) external;

    function remove_liquidity_one_coin(
        uint256 amount,
        int128 i,
        uint256 minAmount
    ) external;

    function remove_liquidity_one_coin(
        uint256 amount,
        int128 i,
        uint256 minAmount,
        bool useUnderlying
    ) external;

    function remove_liquidity_one_coin(
        address pool,
        uint256 amount,
        int128 i,
        uint256 minAmount
    ) external;
}

interface ICurveGauge is IERC20Metadata {
    function lp_token() external view returns (address);

    function reward_contract() external view returns (ICurveRewardClaimer);

    function reward_tokens(uint256 id) external view returns (address);

    function rewards_reciever(address account) external view returns (uint256);

    function reward_balances(address token) external view returns (uint256);

    function reward_integral(address token) external view returns (uint256);

    function reward_integral_for(address token, address account)
        external
        view
        returns (uint256);

    function last_claim() external view returns (uint256);

    function claimed_reward(address account, address token)
        external
        view
        returns (uint256);

    function claimable_reward(address account, address token)
        external
        view
        returns (uint256);

    function claim_sig() external view returns (bytes memory);

    function claimable_reward_write(address account, address token)
        external
        returns (uint256);

    function claim_rewards() external;

    function claim_rewards(address account) external;

    function claim_rewards(address account, address recipient) external;

    function deposit(uint256 amount) external;

    function deposit(uint256 amount, address account) external;

    function deposit(
        uint256 amount,
        address account,
        bool claimRewards
    ) external;

    function withdraw(uint256 amount) external;

    function withdraw(uint256 amount, bool claimRewards) external;

    function set_rewards_receiver(address account) external;
}

interface ICurveGaugeExtension {
    struct Reward {
        address token;
        address distributor;
        uint256 period_finish;
        uint256 rate;
        uint256 last_update;
        uint256 integral;
    }

    function pool() external view returns (ICurvePool);

    function base_gauge() external view returns (ICurveGauge);

    function rewards_receiver(address account) external view returns (address);

    function reward_tokens(uint256 id) external view returns (address);

    function reward_count() external view returns (uint256);

    function reward_data(address reward) external view returns (Reward memory);

    function reward_balances(address token) external view returns (uint256);

    function reward_integral(address token) external view returns (uint256);

    function reward_integral_for(address token, address account)
        external
        view
        returns (uint256);

    function claimed_reward(address account, address token)
        external
        view
        returns (uint256);

    function claimable_reward(address account, address token)
        external
        view
        returns (uint256);

    function claimable_reward_write(address account, address token)
        external
        returns (uint256);

    function checkpoint_rewards(address account) external;

    function claim_rewards() external;

    function claim_rewards(address account) external;

    function claim_rewards(address account, address recipient) external;
}

interface ICurveRewardClaimer {
    struct RewardToken {
        address distributor;
        uint256 period_finish;
        uint256 rate;
        uint256 duration;
        uint256 received;
        uint256 paid;
    }

    function reward_receiver() external view returns (address);

    function reward_tokens(uint256 id) external view returns (address);

    function reward_count() external view returns (uint256);

    function reward_data(address reward)
        external
        view
        returns (RewardToken memory);

    function last_update_time() external view returns (uint256);

    function get_reward() external;
}

/* solhint-enable */
