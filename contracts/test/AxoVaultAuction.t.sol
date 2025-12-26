// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";

import { AxoVault } from "src/AxoVault.sol";
import { AxoToken } from "src/AxoToken.sol";
import { AxoBatchAuction } from "src/AxoBatchAuction.sol";
import { MockERC20 } from "src/mocks/MockERC20.sol";

contract AxoVaultAuctionTest is Test {
    MockERC20 private asset;
    AxoToken private pt;
    AxoToken private yt;

    AxoBatchAuction private auction;
    AxoVault private vault;

    address private alice = address(0xA11CE);
    address private bidder = address(0xB1D);
    uint256 private maturity;

    function setUp() external {
        maturity = block.timestamp + 30 days;
        asset = new MockERC20("Asset", "mUSD", 18);
        pt = new AxoToken("Principal", "PT", address(this));
        yt = new AxoToken("Yield", "YT", address(this));

        auction = new AxoBatchAuction(address(asset), address(yt));
        vault = new AxoVault(address(asset), address(auction), address(pt), address(yt), maturity);

        // Vault must own PT/YT to mint/burn
        pt.transferOwnership(address(vault));
        yt.transferOwnership(address(vault));

        // Fund: Alice has asset to deposit, bidder provides cash liquidity for clearing.
        asset.mint(alice, 1_000e18);
        asset.mint(bidder, 1_000e18);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);

        vm.prank(bidder);
        asset.approve(address(auction), type(uint256).max);

        vm.prank(bidder);
        auction.depositCash(100e18);
    }

    function test_DepositFixed_SellsYTViaAuction_MintsExtraPT() external {
        vm.prank(alice);
        vault.depositFixed(100e18, 100e18);

        // Alice receives 100 PT + proceeds from YT sale.
        // With bidder cash=100 and seller yt=100, seller gets 100 cash.
        assertEq(pt.balanceOf(alice), 200e18);

        // Auction paid the vault, so vault should hold extra cash.
        // The vault keeps assets to back redemptions.
        assertEq(asset.balanceOf(address(vault)), 200e18);
    }

    function test_DepositFixed_RevertsIfNoBids() external {
        // Deploy a fresh vault+auction with no cash deposits.
        AxoToken pt2 = new AxoToken("Principal2", "PT2", address(this));
        AxoToken yt2 = new AxoToken("Yield2", "YT2", address(this));
        AxoBatchAuction emptyAuction = new AxoBatchAuction(address(asset), address(yt2));
        AxoVault emptyVault = new AxoVault(address(asset), address(emptyAuction), address(pt2), address(yt2), maturity);

        pt2.transferOwnership(address(emptyVault));
        yt2.transferOwnership(address(emptyVault));

        vm.prank(alice);
        asset.approve(address(emptyVault), type(uint256).max);

        vm.prank(alice);
        vm.expectRevert(AxoVault.AxoVault__InsufficientLiquidity.selector);
        emptyVault.depositFixed(1e18, 1e18);
    }
}
