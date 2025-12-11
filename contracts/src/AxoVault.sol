// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AxoToken } from "./AxoToken.sol";
import {IMockAMM} from "./interfaces/IMockAMM.sol";


/**
 * @title AxoVault
 * @notice The "Volatility Dam" that splits yield and auto-sells it for fixed returns.
 * @dev This contract allows users to deposit assets and receive fixed yield by selling yield tokens to an AMM
 */
// aderyn-fp-next-line(centralization-risk)
contract AxoVault is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // --- Constants ---
    uint256 private constant MIN_AMOUNT = 0;

    // --- Immutable State Variables ---
    IERC20 public immutable I_ASSET;   // The underlying (mUSD)
    AxoToken public immutable I_PT;    // Principal Token (PMUSD)
    AxoToken public immutable I_YT;    // Yield Token (YMUSD)
    IMockAMM public immutable I_AMM;   // The Liquidity Pool

    // --- State Variables ---
    uint256 public totalDeposits;
    uint256 public totalYieldSold;

    // --- Events ---
    event Deposited(address indexed user, uint256 assetsDeposited, uint256 ptReceived);
    event Redeemed(address indexed user, uint256 ptBurned, uint256 assetsReturned);
    event YieldSold(uint256 ytAmount, uint256 cashReceived);
    event EmergencyWithdraw(address indexed owner, address indexed token, uint256 amount);

    // --- Errors ---
    error AxoVault__AmountZero();
    error AxoVault__MintNotSuccessfull();
    error AxoVault__InsufficientLiquidity();
    error AxoVault__SlippageTooHigh(uint256 expected, uint256 actual);

    constructor(
        address _asset,
        address _amm,
        address _pt,
        address _yt
    ) Ownable(msg.sender) {
        I_ASSET = IERC20(_asset);
        I_PT = AxoToken(_pt);
        I_YT = AxoToken(_yt);
        I_AMM = IMockAMM(_amm);
    }

    // =========================================
    // 🟢 MAIN USER FUNCTION: FIXED YIELD DEPOSIT
    // =========================================
    /**
     * @notice Deposit assets and receive principal tokens with fixed yield
     * @param amount The amount of assets to deposit
     * @param minPtOut The minimum amount of PT tokens to receive (slippage protection)
     */
    function depositFixed(uint256 amount, uint256 minPtOut) external nonReentrant whenNotPaused {
        if (amount == MIN_AMOUNT) revert AxoVault__AmountZero();

        // 1. Pull Asset (mUSD) from User to Vault
        // (User must have approved Vault first!)
        I_ASSET.safeTransferFrom(msg.sender, address(this), amount);

        // 2. Mint Principal Token (PT) to User 1:1
        // This represents their original deposit
        bool ptMintSuccessfull = I_PT.mint(msg.sender, amount);
        if (!ptMintSuccessfull) {
            revert AxoVault__MintNotSuccessfull();
        }

        // 3. Mint Yield Token (YT) to THIS VAULT
        // We hold it temporarily so we can sell it
        bool ytMintSuccessfull = I_YT.mint(address(this), amount);
        if (!ytMintSuccessfull) {
            revert AxoVault__MintNotSuccessfull();
        }

        // 4. Sell the YT for more Cash (mUSD)
        uint256 ytBalance = I_YT.balanceOf(address(this));
        
        // Approve AMM to take our YT
        // (Some implementations might not need this if AMM is trusted, but it's safer)
        // We cast it to IERC20 to use the SafeERC20 library function
        IERC20(address(I_YT)).forceApprove(address(I_AMM), ytBalance);
        
        // Execute the Swap
        // This calls the AMM and gets mUSD back
        uint256 cashReceived = I_AMM.swapYTforCash(ytBalance);

        // 5. Use the extra cash to mint MORE PT for the User
        // This is the "Fixed Yield" being locked in!
        if (cashReceived > MIN_AMOUNT) {
            bool extraPtMintSuccessfull = I_PT.mint(msg.sender, cashReceived);
            if (!extraPtMintSuccessfull) {
                revert AxoVault__MintNotSuccessfull();
            }
        }

        uint256 totalPtReceived = amount + cashReceived;
        
        // Slippage protection
        if (totalPtReceived < minPtOut) {
            revert AxoVault__SlippageTooHigh(minPtOut, totalPtReceived);
        }

        totalDeposits += amount;
        totalYieldSold += cashReceived;

        emit YieldSold(ytBalance, cashReceived);
        emit Deposited(msg.sender, amount, totalPtReceived);
    }

    // =========================================
    // 🔴 WITHDRAW / REDEEM
    // =========================================
    /**
     * @notice Redeem principal tokens for underlying assets
     * @param ptAmount The amount of PT tokens to redeem
     */
    function redeem(uint256 ptAmount) external nonReentrant whenNotPaused {
        if (ptAmount == MIN_AMOUNT) revert AxoVault__AmountZero();

        // Check if vault has enough liquidity
        uint256 vaultBalance = I_ASSET.balanceOf(address(this));
        if (vaultBalance < ptAmount) {
            revert AxoVault__InsufficientLiquidity();
        }

        // 1. Burn the PT from the User
        // (Requires User to approve Vault or use standard burnFrom if allowed)
        // Since we are the Owner of PT contract, we call burnFrom.
        I_PT.burnFrom(msg.sender, ptAmount);

        // 2. Send the original Asset back 1:1
        I_ASSET.safeTransfer(msg.sender, ptAmount);

        // Only subtract from totalDeposits if we have deposits to subtract from
        // Users can redeem yield portion which exceeds original deposits
        if (totalDeposits >= ptAmount) {
            totalDeposits -= ptAmount;
        } else {
            totalDeposits = MIN_AMOUNT;
        }

        emit Redeemed(msg.sender, ptAmount, ptAmount);
    }

    // =========================================
    // 🛡️ ADMIN FUNCTIONS
    // =========================================
    
    /**
     * @notice Pause the contract in case of emergency
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdraw function for stuck tokens
     * @param token The token address to withdraw
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, token, amount);
    }

    // =========================================
    // 📊 VIEW FUNCTIONS
    // =========================================
    
    /**
     * @notice Get the total value locked in the vault
     */
    function getTotalValueLocked() external view returns (uint256) {
        return I_ASSET.balanceOf(address(this));
    }

    /**
     * @notice Get user's PT balance
     */
    function getUserPTBalance(address user) external view returns (uint256) {
        return I_PT.balanceOf(user);
    }

    /**
     * @notice Get user's YT balance
     */
    function getUserYTBalance(address user) external view returns (uint256) {
        return I_YT.balanceOf(user);
    }
}