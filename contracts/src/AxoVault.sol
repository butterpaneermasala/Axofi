// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AxoToken } from "./AxoToken.sol";
import {IMockAMM} from "./interfaces/IMockAMM.sol";


/**
 * @title AxoVault
 * @notice The "Volatility Dam" that splits yield and auto-sells it for fixed returns.
 */
// aderyn-fp-next-line(centralization-risk)
contract AxoVault is Ownable {
    using SafeERC20 for IERC20;

    // --- State Variables ---
    IERC20 public immutable I_ASSET;   // The underlying (mUSD)
    AxoToken public immutable I_PT;    // Principal Token (PMUSD)
    AxoToken public immutable I_YT;    // Yield Token (YMUSD)
    IMockAMM public immutable I_AMM;   // The Liquidity Pool

    // --- Events ---
    event Deposited(address indexed user, uint256 assetsDeposited, uint256 ptReceived);
    event Redeemed(address indexed user, uint256 ptBurned, uint256 assetsReturned);

    // --- Errors ---
    error AxoVault__AmountZero();
    error AxoVault__MintNotSuccessfull();

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
    function depositFixed(uint256 amount) external {
        if (amount == 0) revert AxoVault__AmountZero();

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
        if (cashReceived > 0) {
            bool extraPtMintSuccessfull = I_PT.mint(msg.sender, cashReceived);
            if (!extraPtMintSuccessfull) {
                revert AxoVault__MintNotSuccessfull();
            }
        }

        emit Deposited(msg.sender, amount, amount + cashReceived);
    }

    // =========================================
    // 🔴 WITHDRAW / REDEEM
    // =========================================
    function redeem(uint256 ptAmount) external {
        if (ptAmount == 0) revert AxoVault__AmountZero();

        // 1. Burn the PT from the User
        // (Requires User to approve Vault or use standard burnFrom if allowed)
        // Since we are the Owner of PT contract, we call burnFrom.
        I_PT.burnFrom(msg.sender, ptAmount);

        // 2. Send the original Asset back 1:1
        I_ASSET.safeTransfer(msg.sender, ptAmount);

        emit Redeemed(msg.sender, ptAmount, ptAmount);
    }
}