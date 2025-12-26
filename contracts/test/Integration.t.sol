// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";

import { AxoVault } from "../src/AxoVault.sol";
import { AxoToken } from "../src/AxoToken.sol";
import { AxoBatchAuction } from "../src/AxoBatchAuction.sol";
import { MockERC20 } from "../src/mocks/MockERC20.sol";

/**
 * @notice End-to-end test of the AxoFi v1 flow with batch auction + maturity.
 */
contract IntegrationTest is Test {
    AxoVault public vault;
    AxoToken public pt;
    AxoToken public yt;
    MockERC20 public asset;
    AxoBatchAuction public auction;

    address public alice;
    address public bidder;
    uint256 public maturity;

    function setUp() public {
        alice = makeAddr("alice");
        bidder = makeAddr("bidder");

        maturity = block.timestamp + 10 days;

        asset = new MockERC20("Mantle USD", "mUSD", 18);
        pt = new AxoToken("Principal Token", "PT", address(this));
        yt = new AxoToken("Yield Token", "YT", address(this));
        auction = new AxoBatchAuction(address(asset), address(yt));
        vault = new AxoVault(address(asset), address(auction), address(pt), address(yt), maturity);

        pt.transferOwnership(address(vault));
        yt.transferOwnership(address(vault));

        asset.mint(alice, 1_000e18);
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);

        asset.mint(bidder, 1_000e18);
        vm.prank(bidder);
        asset.approve(address(auction), type(uint256).max);
    }

    function test_FixedDeposit_ThenRedeemAtMaturity() public {
        // Provide auction bids so fixed deposit can clear.
        vm.prank(bidder);
        auction.depositCash(100e18);

        // Alice locks a fixed outcome.
        vm.prank(alice);
        vault.depositFixed(100e18, 100e18);

        // She received uplifted PT.
        assertEq(pt.balanceOf(alice), 200e18);

        // Before maturity, redeem is blocked.
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AxoVault.AxoVault__NotMatured.selector, maturity, block.timestamp)
        );
        vault.redeem(1e18);

        // At maturity, redeem works.
        vm.warp(maturity + 1);
        vm.prank(alice);
        vault.redeem(200e18);
        assertEq(asset.balanceOf(alice), 1_100e18);
    }
}

// NOTE: Legacy AMM-based integration tests were removed; see git history.

