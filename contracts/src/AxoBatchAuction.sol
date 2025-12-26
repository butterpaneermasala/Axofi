// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IAxoAuction } from "./interfaces/IAxoAuction.sol";

/**
 * @title AxoBatchAuction
 * @notice Minimal batch auction for YT <-> Cash (e.g., mUSD).
 *         Users deposit either side into the current epoch. Anyone can clear the epoch once both sides exist.
 *         Clearing sets a uniform clearing price and allows users to claim pro-rata outputs.
 * @dev This is intentionally simple for v1/hackathon use.
 */
contract AxoBatchAuction is IAxoAuction {
    using SafeERC20 for IERC20;

    IERC20 public immutable I_CASH;
    IERC20 public immutable I_YT;

    struct EpochTotals {
        uint256 totalCash;
        uint256 totalYt;
        bool cleared;
    }

    uint256 private s_currentEpoch;

    mapping(uint256 epochId => EpochTotals) public epochs;
    mapping(uint256 epochId => mapping(address user => uint256)) public cashIn;
    mapping(uint256 epochId => mapping(address user => uint256)) public ytIn;

    event CashDeposited(uint256 indexed epochId, address indexed user, uint256 amount);
    event YTDeposited(uint256 indexed epochId, address indexed user, uint256 amount);
    event EpochCleared(uint256 indexed epochId, uint256 totalCash, uint256 totalYt);
    event Claimed(uint256 indexed epochId, address indexed user, uint256 cashOut, uint256 ytOut);

    error AxoBatchAuction__EpochAlreadyCleared();
    error AxoBatchAuction__NothingToClaim();
    error AxoBatchAuction__AmountZero();
    error AxoBatchAuction__CannotClear();

    constructor(address cash, address yt) {
        I_CASH = IERC20(cash);
        I_YT = IERC20(yt);
    }

    function currentEpoch() external view override returns (uint256) {
        return s_currentEpoch;
    }

    function canClearCurrentEpoch() external view override returns (bool) {
        EpochTotals memory e = epochs[s_currentEpoch];
        return (!e.cleared && e.totalCash > 0 && e.totalYt > 0);
    }

    function depositCash(uint256 amount) external override {
        if (amount == 0) revert AxoBatchAuction__AmountZero();
        EpochTotals storage e = epochs[s_currentEpoch];
        if (e.cleared) revert AxoBatchAuction__EpochAlreadyCleared();

        I_CASH.safeTransferFrom(msg.sender, address(this), amount);

        e.totalCash += amount;
        cashIn[s_currentEpoch][msg.sender] += amount;

        emit CashDeposited(s_currentEpoch, msg.sender, amount);
    }

    function depositYT(uint256 amount) external override {
        if (amount == 0) revert AxoBatchAuction__AmountZero();
        EpochTotals storage e = epochs[s_currentEpoch];
        if (e.cleared) revert AxoBatchAuction__EpochAlreadyCleared();

        I_YT.safeTransferFrom(msg.sender, address(this), amount);

        e.totalYt += amount;
        ytIn[s_currentEpoch][msg.sender] += amount;

        emit YTDeposited(s_currentEpoch, msg.sender, amount);
    }

    function clear() external override returns (uint256 clearedEpochId) {
        EpochTotals storage e = epochs[s_currentEpoch];
        if (e.cleared) revert AxoBatchAuction__EpochAlreadyCleared();
        if (e.totalCash == 0 || e.totalYt == 0) revert AxoBatchAuction__CannotClear();

        e.cleared = true;
        clearedEpochId = s_currentEpoch;

        emit EpochCleared(clearedEpochId, e.totalCash, e.totalYt);

        unchecked {
            s_currentEpoch = s_currentEpoch + 1;
        }
    }

    function claim(uint256 epochId) external override returns (uint256 cashOut, uint256 ytOut) {
        EpochTotals memory e = epochs[epochId];
        if (!e.cleared) revert AxoBatchAuction__CannotClear();

        uint256 userCashIn = cashIn[epochId][msg.sender];
        uint256 userYtIn = ytIn[epochId][msg.sender];
        if (userCashIn == 0 && userYtIn == 0) revert AxoBatchAuction__NothingToClaim();

        // Zero out before external calls
        if (userCashIn != 0) cashIn[epochId][msg.sender] = 0;
        if (userYtIn != 0) ytIn[epochId][msg.sender] = 0;

        // Uniform pro-rata clearing
        // Buyers (cashIn) receive YT: ytOut = cashIn * totalYt / totalCash
        // Sellers (ytIn) receive Cash: cashOut = ytIn * totalCash / totalYt
        if (userCashIn != 0) {
            ytOut = (userCashIn * e.totalYt) / e.totalCash;
            if (ytOut != 0) I_YT.safeTransfer(msg.sender, ytOut);
        }

        if (userYtIn != 0) {
            cashOut = (userYtIn * e.totalCash) / e.totalYt;
            if (cashOut != 0) I_CASH.safeTransfer(msg.sender, cashOut);
        }

        emit Claimed(epochId, msg.sender, cashOut, ytOut);
    }
}
