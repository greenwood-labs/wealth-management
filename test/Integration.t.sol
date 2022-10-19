// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "test/state/integration/BaseIntegration.sol";

import "src/libraries/Periodic.sol";

contract IntegrationTest is BaseIntegration {


    // converts returned tuple values into a strategyState struct
    function getStrategyState() public view returns (Periodic.StrategyState memory) {
        (
            uint256 round,
            uint256 lockedAssets,
            uint256 totalPendingDeposits,
            uint256 sharesQueuedForRedemption,
            uint256 assetsUnlockedForRedemption,
            uint256 roundExpiration
        ) = strategy.strategyState();

        return Periodic.StrategyState({
            round: round,
            lockedAssets: lockedAssets,
            totalPendingDeposits: totalPendingDeposits,
            sharesQueuedForRedemption: sharesQueuedForRedemption,
            assetsUnlockedForRedemption: assetsUnlockedForRedemption,
            roundExpiration: roundExpiration
        });
    }

    function getStrategyDeposit(address account) public view returns (Periodic.Deposit memory) {
        (
            uint256 round,
            uint256 amount,
            uint256 unclaimedShares
        ) = strategy.deposits(account);

        return Periodic.Deposit({
            round: round,
            amount: amount,
            unclaimedShares: unclaimedShares
        });
    }


    function _assertInitialMultisigState() private {
        assertEq(weth.balanceOf(client0), 0 ether);
        assertEq(weth.balanceOf(address(safe)), 100 ether);
    }

    function _assertMultisigDeposit() private {
        // RIA proposes a transaction to approve the vault to pull 1 WETH from the multisig
        address proposedApproveTo = address(weth);
        bytes memory proposedApproveTransaction = abi.encodeCall(weth.approve, (address(vault), 1 ether));

        // RIA proposes a transaction to deposit into the vault
        address proposedDepositTo = address(vault);
        bytes memory proposedDepositTransaction = abi.encodeCall(vault.deposit, (1 ether));

        // client executes the approve transaction
        vm.prank(client0);
        assertTrue(module.execTransaction(
            proposedApproveTo, 
            0, 
            proposedApproveTransaction, 
            Enum.Operation.Call
        ));

        // client executes the deposit transaction
        vm.prank(client0);
        assertTrue(module.execTransaction(
            proposedDepositTo,
            0,
            proposedDepositTransaction,
            Enum.Operation.Call
        ));

        // get the Deposit struct for the safe and new strategy state
        Periodic.Deposit memory deposit = getStrategyDeposit(address(safe));
        Periodic.StrategyState memory strategyStatePostDeposit = getStrategyState();

        // post deposit assertions
        assertEq(strategyStatePostDeposit.totalPendingDeposits, 1 ether);
        assertEq(weth.balanceOf(address(strategy)), 1 ether);
        assertEq(deposit.amount, 1 ether);
        assertEq(deposit.round, strategyStatePostDeposit.round);
        assertEq(deposit.unclaimedShares, 0);
    }

    function _assertRollToRoundTwo() private {
        // get the current timestamp
        uint256 roundOneTimestamp = block.timestamp;

        // counterparty approves the transfer of WETH to the strategy
        vm.prank(counterparty);
        weth.approve(address(strategy), 1 ether);

        // counterparty approves the transfer of USDC to the strategy
        vm.prank(counterparty);
        usdc.approve(address(strategy), 1000e6);

        // counterparty creates the the oTokens for the next round.
        // The counterparty account does not *have* to be the one that executes this function
        vm.prank(counterparty);
        strategy.createOtokens(
            200e8,              // $200 long call strike
            200e8,              // $200 long put strike
            150e8,              // $150 short put strike
            roundOneTimestamp,  // use current timestamp to get next friday expiration
            1000e6,             // 1000 USDC as collateral
            1 ether,            // 1 WETH as collateral
            counterparty        // account that will be the counterparty
        );

        // assert oTokens were deployed
        assertTrue(address(strategy.longCallOtoken()) != address(0));
        assertTrue(address(strategy.longPutOtoken()) != address(0));
        assertTrue(address(strategy.shortPutOtoken()) != address(0));

        // assert collateral and counterparty was properly set
        assertEq(strategy.usdcPutCollateral(), 1000e6);
        assertEq(strategy.wethCallCollateral(), 1 ether);
        assertEq(strategy.counterparty(), counterparty);

        // once oTokens have been created, the keeper can roll the vault to the next round
        vm.prank(keeper);
        vault.rollToNextPosition();

        // set the mock oToken asset pricers on the oTokens (this is only needed for testing)
        setMockOtokenAssetPricers(
            strategy.longCallOtoken(), 
            strategy.longPutOtoken(), 
            strategy.shortPutOtoken()
        );
    }

    function _assertRoundTwoState(
        Periodic.StrategyState memory strategyStateBefore, 
        uint256 lpSupplyBefore,
        uint256 roundPricePerShareBefore
    ) private {
        // get round two vault and strategy state
        Periodic.StrategyState memory strategyStateAfter = getStrategyState();
        uint256 lpSupplyAfter = vault.totalSupply();
        uint256 roundPricePerShareAfter = strategy.roundPricePerShare(1);

        // ensure that funds cant instantly be withdrawn from the vault
        vm.prank(client0);
        assertFalse(module.execTransaction(
            address(vault),
            0,
            abi.encodeCall(vault.withdraw, (1 ether)),
            Enum.Operation.Call
        ));

        // assert strategy state displays intended behavior
        assertEq(strategyStateBefore.round, 1);
        assertEq(strategyStateAfter.round, 2);
        assertEq(strategyStateBefore.assetsUnlockedForRedemption, 0);
        assertEq(strategyStateAfter.assetsUnlockedForRedemption, 0);
        assertEq(strategyStateBefore.totalPendingDeposits, 0);
        assertEq(strategyStateAfter.totalPendingDeposits, 0);
        assertEq(strategyStateBefore.lockedAssets, 0);
        assertEq(strategyStateAfter.lockedAssets, 1 ether);
        assertEq(lpSupplyBefore, 0);
        assertEq(lpSupplyAfter, 1 ether);
        assertEq(roundPricePerShareBefore, 0);
        assertEq(roundPricePerShareAfter, 1 ether);

        // assert oTokens were distributed in the proper amounts
        assertEq(ERC20(strategy.longCallOtoken()).balanceOf(address(strategy)), 1e8);
        assertEq(ERC20(strategy.longPutOtoken()).balanceOf(address(strategy)), 0);
        assertEq(ERC20(strategy.shortPutOtoken()).balanceOf(address(counterparty)), 5e8);
    }

    function testIntegration() public {

        // client has funds in the Greenwood multisig
        _assertInitialMultisigState();

        // get round one vault and strategy state
        Periodic.StrategyState memory strategyStateBefore = getStrategyState();
        uint256 lpSupplyBefore = vault.totalSupply();
        uint256 roundPricePerShareBefore = strategy.roundPricePerShare(1);

        // client deposits 1 WETH into the vault via the Greenwood Multisig
        _assertMultisigDeposit();

        // roll to round 2 after client has deposited to the vault
        _assertRollToRoundTwo();

        // check expected behavior after completing a roll to round two
        _assertRoundTwoState(
            strategyStateBefore,
            lpSupplyBefore,
            roundPricePerShareBefore
        );

        
    }
}