// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/Ribbon/IRibbonVault.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";

import "src/libraries/SafeERC20.sol";
import "src/libraries/Wrapper.sol";

contract MockRibbonVault is IERC20, IRibbonVault {
    using SafeERC20 for address;
    using Wrapper for address;

    /************************************************
      *  ERC20 STORAGE
      ***********************************************/

    mapping(address => mapping(address => uint256)) public override allowance;

    mapping(address => uint256) public override balanceOf;

    uint256 public override totalSupply;

    /************************************************
      *  VAULT STORAGE
      ***********************************************/

    address public asset;
    address public wrappedNative;

    uint256 public currentRound;
    uint256 public withdrawInitiatedRound;

    uint256 public depositedFunds;
    uint256 public initiatedWithdrawFunds;

    bool public fundsLocked;

    constructor(
        address _asset, 
        address _wrappedNative,
        uint256 _round
    ) {
        asset = _asset;
        wrappedNative = _wrappedNative;
        currentRound = _round;
    }

    /**
     * @notice Deposits the `asset` from msg.sender.
     * @param amount is the amount of `asset` to deposit
     */
     function deposit(uint256 amount) external override {
        
        asset.safeTransferFrom(msg.sender, address(this), amount);

        depositedFunds += amount;
     }
 
     /**
      * @notice Initiates a withdrawal that can be processed once the round completes
      * @param _shares is the number of shares to withdraw
      */
     function initiateWithdraw(uint128 _shares) external override {
        uint256 fundsFromShares = _shares * asset.getBalanceOf(address(this)) / totalSupply;

        initiatedWithdrawFunds += fundsFromShares;
        withdrawInitiatedRound = currentRound;
     }
 
     /**
      * @notice Completes a scheduled withdrawal from a past round. Uses finalized pps for the round
      */
     function completeWithdraw() external override {
        require(currentRound > withdrawInitiatedRound);

        if (asset == wrappedNative) {
            wrappedNative.unwrap(initiatedWithdrawFunds);
            (bool success, ) = payable(msg.sender).call{value: initiatedWithdrawFunds}("");
            require(success, "Transfer failed");
        } else {
            asset.safeTransfer(msg.sender, initiatedWithdrawFunds);
        }

        _burn(address(this), initiatedWithdrawFunds);
        initiatedWithdrawFunds = 0;
     }
 
     /**
      * @notice Withdraws the assets on the vault using the outstanding `DepositReceipt.amount`
      * @param amount is the amount to withdraw
      */
     function withdrawInstantly(uint256 amount) external override {
        IERC20(asset).transfer(msg.sender, amount);
     }
 
     /************************************************
      *  VAULT OPERATIONS
      ***********************************************/
 
     function rollToNextOption() external override {
        currentRound += 1;

        _mint(address(this), depositedFunds);
        depositedFunds = 0;
     }
 
     /************************************************
      *  GETTERS
      ***********************************************/
 
    function accountVaultBalance(address)
         external
         view
         override
         returns (uint256)
    {
        return IERC20(asset).balanceOf(address(this));
    }

    function shares(address) 
        public 
        view 
        virtual 
        override 
        returns (uint256) 
    {
        return IERC20(address(this)).balanceOf(address(this));
    }

    /************************************************
      *  ERC20 OPERATIONS
      ***********************************************/

     function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount)
        external
        override
        returns (bool)
    {
        balanceOf[msg.sender] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];

        if (allowed != type(uint256).max)
            allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;

        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}