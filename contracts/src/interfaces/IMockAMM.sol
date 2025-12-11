// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IMockAMM {
    /**
     * @notice Swaps Yield Tokens (YT) for Cash (mUSD)
     * @param ytAmount The amount of YT to sell
     * @return The amount of Cash received
     */
    function swapYTforCash(uint256 ytAmount) external returns (uint256);
}