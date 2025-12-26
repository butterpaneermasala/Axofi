// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AxoToken } from "./AxoToken.sol";
import { IAxoAuction } from "./interfaces/IAxoAuction.sol";


/**
 * @title AxoVault
 * @author x@satyaorz
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
    IAxoAuction public immutable I_AUCTION;   // Batch auction venue
    uint256 public immutable I_MATURITY;

    // --- State Variables ---
    uint256 public totalDeposits;
    uint256 public totalYieldSold;

    // --- Events ---
    event Deposited(address indexed user, uint256 assetsDeposited, uint256 ptReceived);
    event FloatingDeposited(address indexed user, uint256 assetsDeposited, uint256 ptReceived, uint256 ytReceived);
    event Redeemed(address indexed user, uint256 ptBurned, uint256 assetsReturned);
    event YieldRedeemed(address indexed user, uint256 ytBurned, uint256 assetsReturned);
    event YieldSold(uint256 ytAmount, uint256 cashReceived);
    event EmergencyWithdraw(address indexed owner, address indexed token, uint256 amount);

    // --- Errors ---
    error AxoVault__AmountZero();
    error AxoVault__MintNotSuccessfull();
    error AxoVault__InsufficientLiquidity();
    error AxoVault__SlippageTooHigh(uint256 expected, uint256 actual);
    error AxoVault__NotMatured(uint256 maturityTimestamp, uint256 currentTimestamp);

    constructor(
        address _asset,
        address _auction,
        address _pt,
        address _yt,
        uint256 _maturityTimestamp
    ) Ownable(msg.sender) {
        I_ASSET = IERC20(_asset);
        I_PT = AxoToken(_pt);
        I_YT = AxoToken(_yt);
        I_AUCTION = IAxoAuction(_auction);
        I_MATURITY = _maturityTimestamp;
    }

    function _revertIfNotMatured() internal view {
        if (block.timestamp < I_MATURITY) revert AxoVault__NotMatured(I_MATURITY, block.timestamp);
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
        // aderyn-fp-next-line(reentrancy-state-change)
        I_ASSET.safeTransferFrom(msg.sender, address(this), amount);

        // 2. Mint Principal Token (PT) to User 1:1
        // This represents their original deposit
        // aderyn-fp-next-line(reentrancy-state-change)
        bool ptMintSuccessfull = I_PT.mint(msg.sender, amount);
        if (!ptMintSuccessfull) {
            revert AxoVault__MintNotSuccessfull();
        }

        // 3. Mint Yield Token (YT) to THIS VAULT
        // We hold it temporarily so we can sell it
        // aderyn-fp-next-line(reentrancy-state-change)
        bool ytMintSuccessfull = I_YT.mint(address(this), amount);
        if (!ytMintSuccessfull) {
            revert AxoVault__MintNotSuccessfull();
        }

        // 4. Sell the YT for more Cash (mUSD) via batch auction
        // aderyn-fp-next-line(reentrancy-state-change)
        uint256 ytBalance = I_YT.balanceOf(address(this));

        // aderyn-fp-next-line(reentrancy-state-change)
        uint256 epochId = I_AUCTION.currentEpoch();

        // Approve auction to take our YT
        IERC20(address(I_YT)).forceApprove(address(I_AUCTION), ytBalance);

        // Deposit YT and attempt to clear immediately.
        // If there are no cash bids, clearing isn't possible and we revert (like old AMM liquidity check).
        // aderyn-fp-next-line(reentrancy-state-change)
        I_AUCTION.depositYT(ytBalance);
        // aderyn-fp-next-line(reentrancy-state-change)
        if (!I_AUCTION.canClearCurrentEpoch()) revert AxoVault__InsufficientLiquidity();

        // aderyn-fp-next-line(reentrancy-state-change)
        uint256 clearedEpochId = I_AUCTION.clear();
        if (clearedEpochId != epochId) revert AxoVault__InsufficientLiquidity();

        // aderyn-fp-next-line(reentrancy-state-change)
        (uint256 cashReceived, ) = I_AUCTION.claim(clearedEpochId);

        // 5. Use the extra cash to mint MORE PT for the User
        // This is the "Fixed Yield" being locked in!
        if (cashReceived > MIN_AMOUNT) {
            // aderyn-fp-next-line(reentrancy-state-change)
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

        // aderyn-fp-next-line(reentrancy-state-change)
        totalDeposits += amount;
        // aderyn-fp-next-line(reentrancy-state-change)
        totalYieldSold += cashReceived;

        emit YieldSold(ytBalance, cashReceived);
        emit Deposited(msg.sender, amount, totalPtReceived);
    }

    /**
     * @notice Deposit assets and receive PT + YT (floating exposure). No auto-sell.
     * @param amount The amount of assets to deposit
     */
    function depositFloating(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == MIN_AMOUNT) revert AxoVault__AmountZero();

        // aderyn-fp-next-line(reentrancy-state-change)
        I_ASSET.safeTransferFrom(msg.sender, address(this), amount);

        // aderyn-fp-next-line(reentrancy-state-change)
        bool ptMintSuccessfull = I_PT.mint(msg.sender, amount);
        if (!ptMintSuccessfull) revert AxoVault__MintNotSuccessfull();

        // aderyn-fp-next-line(reentrancy-state-change)
        bool ytMintSuccessfull = I_YT.mint(msg.sender, amount);
        if (!ytMintSuccessfull) revert AxoVault__MintNotSuccessfull();

        // aderyn-fp-next-line(reentrancy-state-change)
        totalDeposits += amount;

        emit FloatingDeposited(msg.sender, amount, amount, amount);
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

        _revertIfNotMatured();

        // Check if vault has enough liquidity
        // aderyn-fp-next-line(reentrancy-state-change)
        uint256 vaultBalance = I_ASSET.balanceOf(address(this));
        if (vaultBalance < ptAmount) {
            revert AxoVault__InsufficientLiquidity();
        }

        // 1. Burn the PT from the User
        // (Requires User to approve Vault or use standard burnFrom if allowed)
        // Since we are the Owner of PT contract, we call burnFrom.
        // aderyn-fp-next-line(reentrancy-state-change)
        I_PT.burnFrom(msg.sender, ptAmount);

        // 2. Send the original Asset back 1:1
        I_ASSET.safeTransfer(msg.sender, ptAmount);

        // Only subtract from totalDeposits if we have deposits to subtract from
        // Users can redeem yield portion which exceeds original deposits
        if (totalDeposits >= ptAmount) {
            // aderyn-fp-next-line(reentrancy-state-change)
            totalDeposits -= ptAmount;
        } else {
            // aderyn-fp-next-line(reentrancy-state-change)
            totalDeposits = MIN_AMOUNT;
        }

        emit Redeemed(msg.sender, ptAmount, ptAmount);
    }

    /**
     * @notice Redeem YT for residual assets at/after maturity (PT is senior).
     * @dev Uses pro-rata share of (vaultAssets - outstandingPT). Reverts if no residual.
     */
    function redeemYield(uint256 ytAmount, uint256 minAssetsOut) external nonReentrant whenNotPaused {
        if (ytAmount == MIN_AMOUNT) revert AxoVault__AmountZero();

        _revertIfNotMatured();

        // aderyn-fp-next-line(reentrancy-state-change)
        uint256 vaultAssets = I_ASSET.balanceOf(address(this));
        uint256 outstandingPt = I_PT.totalSupply();
        if (vaultAssets <= outstandingPt) revert AxoVault__InsufficientLiquidity();

        uint256 totalYtOutstanding = I_YT.totalSupply();
        if (totalYtOutstanding == MIN_AMOUNT) revert AxoVault__InsufficientLiquidity();

        uint256 yieldAvailable = vaultAssets - outstandingPt;
        uint256 assetsOut = (ytAmount * yieldAvailable) / totalYtOutstanding;
        if (assetsOut < minAssetsOut) revert AxoVault__SlippageTooHigh(minAssetsOut, assetsOut);
        if (assetsOut == MIN_AMOUNT) revert AxoVault__InsufficientLiquidity();

        // aderyn-fp-next-line(reentrancy-state-change)
        I_YT.burnFrom(msg.sender, ytAmount);
        I_ASSET.safeTransfer(msg.sender, assetsOut);

        emit YieldRedeemed(msg.sender, ytAmount, assetsOut);
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