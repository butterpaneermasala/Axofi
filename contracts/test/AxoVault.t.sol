// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";

import { AxoVault } from "../src/AxoVault.sol";
import { AxoToken } from "../src/AxoToken.sol";
import { AxoBatchAuction } from "../src/AxoBatchAuction.sol";
import { MockERC20 } from "../src/mocks/MockERC20.sol";

contract AxoVaultTest is Test {
    AxoVault public vault;
    AxoToken public ptToken;
    AxoToken public ytToken;
    MockERC20 public asset;
    AxoBatchAuction public auction;

    address public owner;
    address public user1;
    address public bidder;

    uint256 public maturity;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        bidder = makeAddr("bidder");

        maturity = block.timestamp + 14 days;

        asset = new MockERC20("Mantle USD", "mUSD", 18);
        ptToken = new AxoToken("Principal Token", "PT", owner);
        ytToken = new AxoToken("Yield Token", "YT", owner);

        auction = new AxoBatchAuction(address(asset), address(ytToken));
        vault = new AxoVault(address(asset), address(auction), address(ptToken), address(ytToken), maturity);

        ptToken.transferOwnership(address(vault));
        ytToken.transferOwnership(address(vault));

        asset.mint(user1, 1_000e18);
        vm.prank(user1);
        asset.approve(address(vault), type(uint256).max);

        asset.mint(bidder, 1_000e18);
        vm.prank(bidder);
        asset.approve(address(auction), type(uint256).max);
    }

    function test_DepositFloating_MintsPTAndYT() public {
        vm.prank(user1);
        vault.depositFloating(100e18);
        assertEq(ptToken.balanceOf(user1), 100e18);
        assertEq(ytToken.balanceOf(user1), 100e18);
    }

    function test_DepositFixed_UsesAuction() public {
        vm.prank(bidder);
        auction.depositCash(100e18);

        vm.prank(user1);
        vault.depositFixed(100e18, 100e18);
        assertEq(ptToken.balanceOf(user1), 200e18);
    }

    function test_RedeemBlockedBeforeMaturity() public {
        vm.prank(user1);
        vault.depositFloating(10e18);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(AxoVault.AxoVault__NotMatured.selector, maturity, block.timestamp)
        );
        vault.redeem(1e18);
    }
}

// NOTE: Legacy AMM-based vault tests were removed; see git history.
