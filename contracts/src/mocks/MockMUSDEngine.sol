// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MockMUSD } from "./MockMUSD.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import {IRebaseToken} from "./MockMUSD.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


using SafeERC20 for IERC20;

/**
 * @notice Simple Logic contract for rebasing mUSD
 */

interface IPriceOracle { function getPrice() external view returns (uint256 price, uint8 decimals); }


contract MockMUSDEngine is Ownable {
    // --- errors ---
    error MUSDEngine__addressCantNotBeZero();
    error MUSDEngine__canNotSetSuchSmallParam();

    // --- events ---
    event Rebased(uint256 oldSupply, uint256 newSupply, int256 supplyDelta);

    // -- state variables ---
    IPriceOracle oracle;
    IRebaseToken token; 

    // JUST FOR TESTING AND MOCK //
    address mnt; // only for testing, here we will be taking mnt sepolia to give out users mUSD
    error MockMUSD__NotAVaildDepositedToken();
    uint256 constant MINTMULTIPLIER = 10_000;
    // JUST FOR TESTING AND MOCK //

    uint256 public targetPrice = 1e18;
    uint256 public minRebaseInterval = 1 hours;
    uint256 public lastRebase;
    uint256 public maxRebaseDeltaBps = 500; // max 5% per rebase (bps = 10000)
    uint256 public constant PRECISION = 18;
    address private immutable I_OWNER;

    constructor(address _oracle, address _token, address _mnt) Ownable(msg.sender) {
        oracle = IPriceOracle(_oracle);
        token = IRebaseToken(_token);
        mnt = _mnt;
        I_OWNER = msg.sender;
    }

    function setParams(uint256 newTargetPrice, uint256 newMinRebaseInterval, address _oracle, address _token) external onlyOwner {
        if (_oracle == address(0x0) || _token == address(0x0)) revert MUSDEngine__addressCantNotBeZero();
        if (newTargetPrice < 1 || newMinRebaseInterval < 5 minutes) revert MUSDEngine__canNotSetSuchSmallParam();
        targetPrice = newTargetPrice;
        minRebaseInterval = newMinRebaseInterval;
        oracle = IPriceOracle(_oracle);
        token = IRebaseToken(_token);
    }
    /**
     * @param price current price of the the token mUSD depends on (USDY) 
     * @param priceDecimals the number decimal places USDY has, this parameter is need to normalize the prices
     * @param currentSupply current supply of mUSD (external)
     */
    function computeSupplyDelta(uint256 price, uint8 priceDecimals, uint256 currentSupply) public view returns (int256) {
        // Normalize price to 18 decimals
        uint256 normalizedPrice = price * (10 ** (PRECISION - priceDecimals));
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

    // JUST FOR TESTING AND MOCK //
    /**
     * @notice faucet anyone can interact with by depositing and get mUSD to test on our protcol
     */
    function getFaucet(address user, address fToken, uint256 fTokenAmount) public {
        if (fToken != mnt) revert MockMUSD__NotAVaildDepositedToken(); // rever if the user is not sending mnt
        // pull payment (will revert on failure)
        IERC20(fToken).safeTransferFrom(user, address(this), fTokenAmount);
        // for every 1 mnt sepolia received we mint 10_000 mUSD, // JUST for testing
        uint256 amountToCredit = fTokenAmount * MINTMULTIPLIER;
        IERC20(address(token)).safeTransfer(user, amountToCredit);
    }

    function windrawMnt() public onlyOwner {
        uint256 mntBalance = IERC20(mnt).balanceOf(address(this));
        if (mntBalance == 0) return;
        IERC20(mnt).safeTransfer(I_OWNER, mntBalance);
    }
    // JUST FOR TESTING AND MOCK //
    
}

