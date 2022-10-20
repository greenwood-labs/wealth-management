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

    function getStrategyRedemption(address account) public view returns (Periodic.Redemption memory) {
        (
            uint256 round,
            uint256 shares
        ) = strategy.redemptions(account);

        return Periodic.Redemption({
            round: round,
            shares: shares
        });
    }

    function _assertInitialMultisigState() private {
        assertEq(weth.balanceOf(client0), 0 ether);
        assertEq(weth.balanceOf(address(safe)), 100 ether);
    }

    function _assertInitialVaultAndStrategyState() private {
        // get round one vault and strategy state
        Periodic.StrategyState memory strategyState = getStrategyState();
        uint256 lpSupply = vault.totalSupply();
        uint256 roundPricePerShare = strategy.roundPricePerShare(1);

        // assert initial vault and strategy state
        assertEq(strategyState.round, 1);
        assertEq(strategyState.assetsUnlockedForRedemption, 0);
        assertEq(strategyState.totalPendingDeposits, 0);
        assertEq(strategyState.lockedAssets, 0);
        assertEq(lpSupply, 0);
        assertEq(roundPricePerShare, 0);
    }

    function _assertMultisigDeposit() private {
        // RIA proposes a transaction to approve the vault to pull 1 WETH from the multisig
        address proposedApproveTo = address(weth);
        bytes memory proposedApproveTransaction = abi.encodeCall(weth.approve, (address(vault), 1 ether));

        console.log("RIA proposes a transaction to approve the vault to pull 1 WETH from the multisig");
        console.log("Transaction: weth.approve(address(vault), 1 ether)");
        console.log("Encoded transaction:");
        console.logBytes(proposedApproveTransaction);
        console.log("");

        // RIA proposes a transaction to deposit into the vault
        address proposedDepositTo = address(vault);
        bytes memory proposedDepositTransaction = abi.encodeCall(vault.deposit, (1 ether));

        console.log("RIA proposes a transaction to deposit into the vault");
        console.log("Transaction: vault.deposit(1 ether)");
        console.log("Encoded transaction:");
        console.logBytes(proposedDepositTransaction);
        console.log("");

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

        console.log("Client executes both transactions via module.execTransaction()");
        console.log("");

        // get the Deposit struct for the safe and new strategy state
        Periodic.Deposit memory deposit = getStrategyDeposit(address(safe));
        Periodic.StrategyState memory strategyStatePostDeposit = getStrategyState();

        // post deposit assertions
        assertEq(strategyStatePostDeposit.totalPendingDeposits, 1 ether);
        assertEq(weth.balanceOf(address(strategy)), 1 ether);
        assertEq(deposit.amount, 1 ether);
        assertEq(deposit.round, strategyStatePostDeposit.round);
        assertEq(deposit.unclaimedShares, 0);

        console.log("Vault total pending deposits:  ", strategyStatePostDeposit.totalPendingDeposits / 1e18, "WETH");
        console.log("Gnosis Safe WETH balance:      ", weth.balanceOf(address(safe)) / 1e18, "WETH");
    }

    function _assertRollToNextRound(
        uint256 longCallStrike,
        uint256 longPutStrike,
        uint256 shortPutStrike,
        uint256 usdcCollateral,
        uint256 wethCollateral
    ) private {
        // counterparty approves the transfer of WETH to the strategy
        vm.prank(counterparty);
        weth.approve(address(strategy), wethCollateral);

        // counterparty approves the transfer of USDC to the strategy
        vm.prank(counterparty);
        usdc.approve(address(strategy), usdcCollateral);

        // counterparty creates the the oTokens for the next round.
        // The counterparty account does not *have* to be the one that executes this function
        vm.prank(counterparty);
        strategy.createOtokens(
            longCallStrike,            
            longPutStrike,           
            shortPutStrike,              
            block.timestamp,    // use current timestamp to get next friday expiration
            usdcCollateral,         
            wethCollateral,       
            counterparty        // account that will be the counterparty
        );

        console.log("Counterparty creates the oTokens for the new round with strike prices:");
        console.log("   Long Call Strike: ", longCallStrike / 1e8, "USD");
        console.log("   Long Put Strike:  ", longPutStrike / 1e8, "USD");
        console.log("   Short Put Strike: ", shortPutStrike / 1e8, "USD");
        console.log("");

        console.log("Counterparty collateralizes oTokens with:");
        console.log("   USDC Collateral:  ", usdcCollateral / 1e6, "USDC");
        console.log("   WETH Collateral:  ", wethCollateral / 1e18, "WETH");
        console.log("");

        // assert oTokens were deployed
        assertTrue(address(strategy.longCallOtoken()) != address(0));
        assertTrue(address(strategy.longPutOtoken()) != address(0));
        assertTrue(address(strategy.shortPutOtoken()) != address(0));

        // assert collateral and counterparty was properly set
        assertEq(strategy.usdcPutCollateral(), usdcCollateral);
        assertEq(strategy.wethCallCollateral(), wethCollateral);
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

        console.log("Long Call oToken: ", address(strategy.longCallOtoken()));
        console.log("Long Put oToken:  ", address(strategy.longPutOtoken()));
        console.log("Short Put oToken: ", address(strategy.shortPutOtoken()));
        console.log("");
    }

    function _assertRoundTwoState() private {
        // get round two vault and strategy state
        Periodic.StrategyState memory strategyState = getStrategyState();
        uint256 lpSupply = vault.totalSupply();
        uint256 roundPricePerShare = strategy.roundPricePerShare(1);

        // ensure that funds cant instantly be withdrawn from the vault
        vm.prank(client0);
        assertFalse(module.execTransaction(
            address(vault),
            0,
            abi.encodeCall(vault.withdraw, (1 ether)),
            Enum.Operation.Call
        ));

        // assert strategy state displays intended behavior
        assertEq(strategyState.round, 2);
        assertEq(strategyState.assetsUnlockedForRedemption, 0);
        assertEq(strategyState.totalPendingDeposits, 0);
        assertEq(strategyState.lockedAssets, 1 ether);
        assertEq(lpSupply, 1 ether);
        assertEq(roundPricePerShare, 1 ether);

        // assert oTokens were distributed in the proper amounts
        assertEq(ERC20(strategy.longCallOtoken()).balanceOf(address(strategy)), 1e8);
        assertEq(ERC20(strategy.longPutOtoken()).balanceOf(address(strategy)), 0);
        assertEq(ERC20(strategy.shortPutOtoken()).balanceOf(address(counterparty)), 5e8);
    }

    function _assertInitiateRedeem() private {
        // initial balance of vault lp tokens
        uint256 lpBalanceInitial = vault.balanceOf(address(safe));

        // RIA proposes a transaction to claim all shares from the vault
        address proposedClaimSharesTo = address(vault);
        bytes memory proposedClaimSharesTransaction = abi.encodeCall(vault.claimShares, (type(uint256).max));

        console.log("RIA proposes a transaction to claim all shares from the vault");
        console.log("Transaction: vault.claimShares(MAX_UINT256)");
        console.log("Encoded transaction:");
        console.logBytes(proposedClaimSharesTransaction);
        console.log("");

        // client executes the claim shares transaction
        vm.prank(client0);
        assertTrue(module.execTransaction(
            proposedClaimSharesTo, 
            0, 
            proposedClaimSharesTransaction, 
            Enum.Operation.Call
        ));

        console.log("Client executes transaction to claim the shares");
        console.log("");

        // lp balance after claiming shares
        uint256 lpBalanceAfterClaim = vault.balanceOf(address(safe));

        console.log("Gnosis Safe vault LP balance:  ", lpBalanceAfterClaim / 1e18);
        console.log("");

        // RIA proposes a transaction to approve the vault to pull all lp tokens from the multisig
        address proposedApproveTo = address(vault);
        bytes memory proposedApproveTransaction = abi.encodeCall(vault.approve, (address(vault), lpBalanceAfterClaim));

        console.log("RIA proposes a transaction to approve the vault to pull all lp tokens from the multisig");
        console.log("Transaction: vault.approve(vault, vault.balanceOf(address(safe)))");
        console.log("Encoded transaction:");
        console.logBytes(proposedApproveTransaction);
        console.log("");

        // RIA proposes a transaction to initiate the redemption of lp shares for the underlying asset
        address proposedInitiateRedeemTo = address(vault);
        bytes memory proposedInitiateRedeemTransaction = abi.encodeCall(vault.initiateRedeem, (lpBalanceAfterClaim));

        console.log("RIA proposes a transaction to initiate the redemption of lp shares for the underlying asset");
        console.log("Transaction: vault.initiateRedeem(vault.balanceOf(address(safe)))");
        console.log("Encoded transaction:");
        console.logBytes(proposedInitiateRedeemTransaction);
        console.log("");

        // client executes the approve transaction
        vm.prank(client0);
        assertTrue(module.execTransaction(
            proposedApproveTo, 
            0, 
            proposedApproveTransaction, 
            Enum.Operation.Call
        ));

        // client executes the initiate redeem transaction
        vm.prank(client0);
        assertTrue(module.execTransaction(
            proposedInitiateRedeemTo, 
            0, 
            proposedInitiateRedeemTransaction, 
            Enum.Operation.Call
        ));

        console.log("Client executes both transactions via module.execTransaction()");
        console.log("");

        // get strategy state after initiating redeem
        Periodic.StrategyState memory strategyState = getStrategyState();
        Periodic.Redemption memory redemption = getStrategyRedemption(address(safe));
        uint256 lpBalanceAfterInitiateRedeem = vault.balanceOf(address(safe));

        // assert lp balances are correct
        assertEq(lpBalanceInitial, 0);
        assertEq(lpBalanceAfterClaim, 1 ether);
        assertEq(lpBalanceAfterInitiateRedeem, 0);

        // assert redemption values are correct
        assertEq(redemption.round, strategyState.round);
        assertEq(redemption.shares, lpBalanceAfterClaim);

        // assert shares queued for redemption are correct
        assertEq(strategyState.sharesQueuedForRedemption, lpBalanceAfterClaim);

        console.log("Vault shares queued for redemption:  ", strategyState.sharesQueuedForRedemption / 1e18);
    }

    function _assertCloseRoundAndPayout() private {
        // speed time up until right after the expiry timestamp
        vm.warp(strategy.currentExpiry() + 1);

        // mock the underlying asset price to $300 to expire in the money for the long call oTokens
        setWethExpirySpotPrice(300e8, strategy.currentExpiry());

        // speed up past the Gamma Protocol dispute period
        vm.warp(block.timestamp + 1 days);

        // get short put oToken address before it is removed from the strategy
        address shortPutOtoken = strategy.shortPutOtoken();

        // keeper commits and closes the current round
        vm.prank(keeper);
        vault.commitAndClose();

        // speed up time to get oToken expiry in sync with round expiry
        Periodic.StrategyState memory strategyState = getStrategyState();
        vm.warp(strategyState.roundExpiration + 1);

        // WETH price ended at $300 with a call strike price of $200, so 
        // $100 of WETH is entitled to the strategy, which is 0.333333 WETH.
        // There is also an underlying 1 WETH that was deposited, so total strategy
        // WETH holdings should be 1.33333 WETH
        assertEq(weth.balanceOf(address(strategy)), 1.333333333333333333 ether);

        // assert that the counterparty still has unredeemed oTokens
        assertEq(ERC20(shortPutOtoken).balanceOf(counterparty), 5e8);

        console.log(
            "WETH price ended at $300 with a call strike price of $200, so\n",
            " $100 of WETH is entitled to the strategy, which is 0.333333 WETH.\n",
            " There is also an underlying 1 WETH that was deposited, so total strategy\n",
            " WETH holdings should be 1.33333 WETH"
        );
        console.log("");

        console.log("Strategy WETH payout:                  ", weth.balanceOf(address(strategy)));
        console.log("Counterparty short put oToken balance: ", ERC20(shortPutOtoken).balanceOf(counterparty) / 1e8, "oTokens");
    }

    function _assertRoundThreeState() private {
        // get round three vault and strategy state
        Periodic.StrategyState memory strategyState = getStrategyState();
        uint256 safeWethBalance = weth.balanceOf(address(safe));
        Periodic.Redemption memory redemption = getStrategyRedemption(address(safe));

        // assert strategy state displays intended behavior
        assertEq(strategyState.round, 3);
        assertEq(strategyState.assetsUnlockedForRedemption, 1.333333333333333333 ether);
        assertEq(safeWethBalance, 99 ether);
        assertEq(redemption.shares, 1 ether);
    }

    function _assertRedeem() private {
        // RIA proposes a transaction to complete the redemption of lp shares for the underlying asset
        address proposedRedeemTo = address(vault);
        bytes memory proposedRedeemTransaction = abi.encodeCall(vault.redeem, ());

        console.log("RIA proposes a transaction to complete the redemption of lp shares for the underlying asset");
        console.log("Transaction: vault.redeem()");
        console.log("Encoded transaction:");
        console.logBytes(proposedRedeemTransaction);
        console.log("");

        // client executes the redeem transaction
        vm.prank(client0);
        assertTrue(module.execTransaction(
            proposedRedeemTo, 
            0, 
            proposedRedeemTransaction, 
            Enum.Operation.Call
        ));

        console.log("Client executes transaction via module.execTransaction()");
        console.log("");

        // get vault and strategy state
        Periodic.StrategyState memory strategyState = getStrategyState();
        uint256 safeWethBalance = weth.balanceOf(address(safe));
        Periodic.Redemption memory redemption = getStrategyRedemption(address(safe));
        uint256 lpTotalSupply = vault.totalSupply();

        // assert strategy state displays intended behavior
        assertEq(strategyState.assetsUnlockedForRedemption, 0);
        assertEq(strategyState.sharesQueuedForRedemption, 0);
        assertEq(safeWethBalance, 100.333333333333333333 ether);
        assertEq(lpTotalSupply, 0);
        assertEq(redemption.shares, 0);

        console.log(
            "The Gnosis Safe redeems the LP shares for 1.3333 WETH. Leaving the\n",
            " safe with a total of 103.33333 WETH, which is a gain of 0.33333 WETH."
        );
        console.log("");

        console.log("Vault assets unlocked for redemption:  ", strategyState.assetsUnlockedForRedemption);
        console.log("Safe WETH Balance after redemption:    ", safeWethBalance);
    }

    function testIntegration() public {

        // make sure client has funds in the Greenwood multisig
        _assertInitialMultisigState();

        // make sure the vault and strategy are in the correct initial state
        _assertInitialVaultAndStrategyState();

        console.log("");
        console.log("##############################################");
        console.log("###      DEPOSIT INTO GREENWOOD VAULT      ###");
        console.log("##############################################");
        console.log("");

        // client deposits 1 WETH into the vault via the Greenwood Multisig
        _assertMultisigDeposit();

        console.log("");
        console.log("##############################################");
        console.log("###       VAULT ROLLOVER TO ROUND 2        ###");
        console.log("##############################################");
        console.log("");

        // roll to round two
        _assertRollToNextRound(
            200e8,  // $200 long call strike
            200e8,  // $200 long put strike
            150e8,  // $150 short put strike
            1000e6, // 1000 USDC as collateral
            1 ether // 1 WETH as collateral
        );

        // check expected behavior after completing a roll to round two
        _assertRoundTwoState();

        console.log("");
        console.log("##############################################");
        console.log("###       INITIATE REDEEM FROM VAULT       ###");
        console.log("##############################################");
        console.log("");

        // Initiate a redemption to eventually redeem shares for underlying asset
        _assertInitiateRedeem(); 

        console.log("");
        console.log("##############################################");
        console.log("###          VAULT CLOSE ROUND 2           ###");
        console.log("##############################################");
        console.log("");
        
        // Close round two and calculate payouts for lp holders and the counterparty
        _assertCloseRoundAndPayout();

        console.log("");
        console.log("##############################################");
        console.log("###       VAULT ROLLOVER TO ROUND 3        ###");
        console.log("##############################################");
        console.log("");

        // roll to round three
        _assertRollToNextRound(
            300e8,  // $300 long call strike
            300e8,  // $300 long put strike
            200e8,  // $200 short put strike
            1000e6, // 1000 USDC as collateral
            1 ether // 1 WETH as collateral
        );

        // check expected behavior after completing a roll to round three
        _assertRoundThreeState();

        console.log("");
        console.log("##############################################");
        console.log("###            REDEEM FROM VAULT           ###");
        console.log("##############################################");
        console.log("");

        // Redeem shares for underlying asset
        _assertRedeem();
    }
}