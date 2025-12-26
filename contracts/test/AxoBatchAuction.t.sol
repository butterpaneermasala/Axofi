// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";

import { AxoBatchAuction } from "src/AxoBatchAuction.sol";
import { MockERC20 } from "src/mocks/MockERC20.sol";

contract AxoBatchAuctionTest is Test {
    MockERC20 private cash;
    MockERC20 private yt;
    AxoBatchAuction private auction;

    address private seller = address(0xA11CE);
    address private buyer = address(0xB0B);

    function setUp() external {
        cash = new MockERC20("Cash", "CASH", 18);
        yt = new MockERC20("Yield", "YT", 18);
        auction = new AxoBatchAuction(address(cash), address(yt));

        cash.mint(buyer, 1_000e18);
        yt.mint(seller, 1_000e18);

        vm.prank(buyer);
        cash.approve(address(auction), type(uint256).max);
        vm.prank(seller);
        yt.approve(address(auction), type(uint256).max);
    }

    function test_ClearAndClaim_ProRata() external {
        // Buyer deposits 100 cash, seller deposits 50 yt.
        vm.prank(buyer);
        auction.depositCash(100e18);

        vm.prank(seller);
        auction.depositYT(50e18);

        uint256 epochId = auction.currentEpoch();
        assertEq(epochId, 0);

        auction.clear();

        // Buyer receives all YT (50) for 100 cash.
        vm.prank(buyer);
        (uint256 cashOutBuyer, uint256 ytOutBuyer) = auction.claim(0);
        assertEq(cashOutBuyer, 0);
        assertEq(ytOutBuyer, 50e18);

        // Seller receives all cash (100) for 50 yt.
        vm.prank(seller);
        (uint256 cashOutSeller, uint256 ytOutSeller) = auction.claim(0);
        assertEq(cashOutSeller, 100e18);
        assertEq(ytOutSeller, 0);

        assertEq(cash.balanceOf(seller), 100e18);
        assertEq(yt.balanceOf(buyer), 50e18);
    }

    function test_Revert_ClearWithoutBothSides() external {
        vm.prank(seller);
        auction.depositYT(10e18);

        vm.expectRevert();
        auction.clear();
    }
}
