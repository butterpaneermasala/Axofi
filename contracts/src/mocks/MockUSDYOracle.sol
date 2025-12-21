// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDYOracle
 * @notice Simple mock oracle whose USD price grows linearly at a configurable annual rate (approx. AYP).
 *         Default behavior models 5% AYP linear growth from an initial price.
 *
 * Pricing units: `initialPrice` and returned `price` are scaled by `decimals` (default 18).
 */
contract MockUSDYOracle is Ownable {
    uint8 public decimals = 18;

    // initial price scaled by `decimals` (eg 1e18 => $1.00)
    uint256 public initialPrice;
    // timestamp when initialPrice took effect
    uint256 public startTimestamp;

    // annual rate in basis points (bps). 500 = 5.00%
    uint256 public annualRateBps = 500;

    uint256 public constant BPS = 10000;
    uint256 public constant YEAR = 365 days;

    event PriceParamsSet(uint256 initialPrice, uint256 startTimestamp, uint256 annualRateBps);

    constructor(uint256 _initialPrice) Ownable(_msgSender()){
        require(_initialPrice > 0, "initialPrice>0");
        initialPrice = _initialPrice;
        startTimestamp = block.timestamp;
        emit PriceParamsSet(initialPrice, startTimestamp, annualRateBps);
    }

    /// @notice Owner can set params for testing
    function setParams(uint256 _initialPrice, uint256 _startTimestamp, uint256 _annualRateBps) external onlyOwner {
        require(_initialPrice > 0, "initialPrice>0");
        initialPrice = _initialPrice;
        startTimestamp = _startTimestamp;
        annualRateBps = _annualRateBps;
        emit PriceParamsSet(initialPrice, startTimestamp, annualRateBps);
    }

    /// @notice Get current price and decimals. Price is scaled by `decimals`.
    function getPrice() external view returns (uint256 price, uint8 priceDecimals) {
        uint256 elapsed = block.timestamp - startTimestamp;

        // linear growth approximation (no compounding):
        // price = initialPrice + (initialPrice * annualRateBps * elapsed) / (BPS * YEAR)
        // compute ratePerYearPrice = (initialPrice * annualRateBps) / BPS first to avoid huge intermediate
        uint256 ratePerYearPrice = (initialPrice * annualRateBps) / BPS;
        uint256 increment = (ratePerYearPrice * elapsed) / YEAR;
        price = initialPrice + increment;
        priceDecimals = decimals;
    }

    /// @notice Helper: get price for an arbitrary timestamp (useful for tests)
    function getPriceAt(uint256 timestamp) external view returns (uint256 price, uint8 priceDecimals) {
        require(timestamp >= startTimestamp, "before start");
        uint256 elapsed = timestamp - startTimestamp;
        uint256 ratePerYearPrice = (initialPrice * annualRateBps) / BPS;
        uint256 increment = (ratePerYearPrice * elapsed) / YEAR;
        price = initialPrice + increment;
        priceDecimals = decimals;
    }
}
