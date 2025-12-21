// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MockMUSD } from "./MockMUSD.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice Simple Logic contract for rebasing mUSD
 */

interface IPriceOracle { function getPrice() external view returns (uint256 price, uint8 decimals); }
interface IRebaseToken { function totalSupply() external view returns (uint256); function rebase(int256 supplyDelta) external; }

contract MockMUSDEngine is Ownable {
    // --- errors ---
    error MUSDEngine__addressCantNotBeZero();
    error MUSDEngine__canNotSetSuchSmallParam();

    // --- events ---
    event Rebased(uint256 oldSupply, uint256 newSupply, int256 supplyDelta);

    // -- state variables ---
    IPriceOracle oracle;
    IRebaseToken token; 

    uint256 public targetPrice = 1e18;
    uint256 public minRebaseInterval = 1 hours;
    uint256 public lastRebase;
    uint256 public maxRebaseDeltaBps = 500; // max 5% per rebase (bps = 10000)

    constructor(address _oracle, address _token) Ownable(msg.sender) {
        oracle = IPriceOracle(_oracle);
        token = IRebaseToken(_token);
    }

    function setParams(uint256 newTargetPrice, uint256 newMinRebaseInterval, address _oracle, address _token) external onlyOwner {
        if (_oracle == address(0x0) || _token == address(0x0)) revert MUSDEngine__addressCantNotBeZero();
        if (newTargetPrice < 1 || newMinRebaseInterval < 5 minutes) revert MUSDEngine__canNotSetSuchSmallParam();
        targetPrice = newTargetPrice;
        minRebaseInterval = newMinRebaseInterval;
        oracle = IPriceOracle(_oracle);
        token = IRebaseToken(_token);
    }

    function computeSupplyDelta(uint256 price, uint8 priceDecimals, uint256 currentSupply) public view returns (int256) {
        // Normalize price to 18 decimals
        uint256 normalizedPrice = price * (10 ** (18 - priceDecimals));
        // desiredSupply = currentSupply * (normalizedPrice / targetPrice)
        // supplyDelta = desiredSupply - currentSupply
        // compute in uint256 then convert to int256 with signs
        uint256 desiredSupply = (currentSupply * normalizedPrice) / targetPrice;
        if (desiredSupply == currentSupply) return 0;
        // cap delta
        if (desiredSupply > currentSupply) {
            uint256 maxIncrease = (currentSupply * maxRebaseDeltaBps) / 10000;
            uint256 increase = desiredSupply - currentSupply;
            if (increase > maxIncrease) desiredSupply = currentSupply + maxIncrease;
        } else {
            uint256 maxDecrease = (currentSupply * maxRebaseDeltaBps) / 10000;
            uint256 decrease = currentSupply - desiredSupply;
            if (decrease > maxDecrease) desiredSupply = currentSupply - maxDecrease;
        }
        int256 delta = int256(desiredSupply > currentSupply ? desiredSupply - currentSupply : 0) - int256(desiredSupply < currentSupply ? currentSupply - desiredSupply : 0);
        return delta;
    }

    function checkAndRebase() external {
        require(block.timestamp - lastRebase >= minRebaseInterval, "too soon");
        (uint256 price, uint8 decimals) = oracle.getPrice();
        uint256 supply = token.totalSupply();
        int256 delta = computeSupplyDelta(price, decimals, supply);
        if (delta != 0) {
            token.rebase(delta);
            lastRebase = block.timestamp;
            uint256 newSupply = token.totalSupply();
            emit Rebased(supply, newSupply, delta);
        }
    }


    
}

