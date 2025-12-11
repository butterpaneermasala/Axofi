// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMockAMM } from "../interfaces/IMockAMM.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockAMM is IMockAMM {
    using SafeERC20 for IERC20;

    // --- Immutable State Variables ---
    IERC20 public immutable I_M_USD; // mUSD
    IERC20 public immutable I_YT;    // Yield Token

    // --- Constants ---
    // The Price: 1 YT = 0.05 mUSD (Implies 5% APY)
    uint256 public constant YIELD_RATE_PERCENT = 5; // 5% annual yield
    uint256 public constant YIELD_PRICE = 0.05 ether; // 5% in 18 decimal format
    uint256 private constant PRECISION = 1e18;
    uint256 private constant PERCENT_DENOMINATOR = 100;

    constructor(address _mUSD, address _yt) {
        I_M_USD = IERC20(_mUSD);
        I_YT = IERC20(_yt);
    }

    /**
     * @notice Buys YT from the sender and pays them in mUSD
     * @param ytAmount The amount of Yield Tokens being sold
     */
    function swapYTforCash(uint256 ytAmount) external override returns (uint256) {
        // 1. Calculate how much Cash to pay
        // Logic: If I sell 100 YT, I get 5 mUSD
        uint256 cashToPay = (ytAmount * YIELD_PRICE) / PRECISION;

        // 2. Transfer the YT from the Vault to Us (The AMM)
        // (We assume the Vault has already approved us)
        I_YT.safeTransferFrom(msg.sender, address(this), ytAmount);
        
        // 3. Check if we have enough Cash to pay
        uint256 ammBalance = I_M_USD.balanceOf(address(this));
        require(ammBalance >= cashToPay, "MockAMM: Out of Liquidity");

        // 4. Pay the Vault
        I_M_USD.safeTransfer(msg.sender, cashToPay);

        return cashToPay;
    }
}