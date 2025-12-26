// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";

import { AxoVault } from "src/AxoVault.sol";
import { AxoToken } from "src/AxoToken.sol";
import { AxoBatchAuction } from "src/AxoBatchAuction.sol";
import { MockERC20 } from "src/mocks/MockERC20.sol";

contract AxoVaultMaturityTest is Test {
    MockERC20 private asset;
    AxoToken private pt;
    AxoToken private yt;
    AxoBatchAuction private auction;
    AxoVault private vault;

    address private alice = address(0xA11CE);

    uint256 private maturity;

    function setUp() external {
        maturity = block.timestamp + 7 days;

        asset = new MockERC20("Asset", "mUSD", 18);
        pt = new AxoToken("Principal", "PT", address(this));
        yt = new AxoToken("Yield", "YT", address(this));

        auction = new AxoBatchAuction(address(asset), address(yt));
        vault = new AxoVault(address(asset), address(auction), address(pt), address(yt), maturity);

        pt.transferOwnership(address(vault));
        yt.transferOwnership(address(vault));

        asset.mint(alice, 1_000e18);
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
    }

    function test_RedeemRevertsBeforeMaturity() external {
        vm.prank(alice);
        vault.depositFloating(100e18);

        uint256 nowTs = block.timestamp;
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AxoVault.AxoVault__NotMatured.selector, maturity, nowTs));
        vault.redeem(1e18);
    }

    function test_PT_Senior_YT_GetsResidual_AfterMaturity() external {
        vm.prank(alice);
        vault.depositFloating(100e18);

        // Simulate yield accrual by adding 10 mUSD to the vault.
        asset.mint(address(vault), 10e18);

        vm.warp(maturity + 1);

        // Redeem PT first (senior)
        vm.prank(alice);
        vault.redeem(100e18);
        assertEq(asset.balanceOf(alice), 1_000e18);

        // Now redeem YT for residual
        vm.prank(alice);
        vault.redeemYield(100e18, 10e18);
        assertEq(asset.balanceOf(alice), 1_010e18);
    }

    function test_YT_CannotDrainPrincipal() external {
        vm.prank(alice);
        vault.depositFloating(100e18);

        // No yield added.
        vm.warp(maturity + 1);

        vm.prank(alice);
        vm.expectRevert(AxoVault.AxoVault__InsufficientLiquidity.selector);
        vault.redeemYield(1e18, 0);

        // PT still redeems fine.
        vm.prank(alice);
        vault.redeem(100e18);
        assertEq(asset.balanceOf(alice), 1_000e18);
    }
}
