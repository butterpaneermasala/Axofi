// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IAxoAuction {
    function currentEpoch() external view returns (uint256);

    function depositCash(uint256 amount) external;

    function depositYT(uint256 amount) external;

    /// @notice Clears the current epoch if both sides are non-zero; starts a new epoch.
    /// @return clearedEpochId The epoch that was just cleared.
    function clear() external returns (uint256 clearedEpochId);

    /// @notice Claims the caller's proceeds/refunds for a cleared epoch.
    /// @dev Returns (cashOut, ytOut) actually transferred.
    function claim(uint256 epochId) external returns (uint256 cashOut, uint256 ytOut);

    function canClearCurrentEpoch() external view returns (bool);
}
