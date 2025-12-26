// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import "../src/mocks/MockAMM.sol";
import "../src/mocks/MockERC20.sol";
import "../src/AxoToken.sol";

contract MockAMMTest is Test {
    MockAMM public amm;
    MockERC20 public cash;
    AxoToken public ytToken;

    address public owner;
    address public trader;

    function setUp() public {
        owner = address(this);
        trader = makeAddr("trader");

        cash = new MockERC20("Mantle USD", "mUSD", 18);
        ytToken = new AxoToken("Yield Token", "YT", owner);

        amm = new MockAMM(address(cash), address(ytToken));

        // Fund AMM with liquidity
        cash.mint(address(amm), 100_000e18);

        // Mint YT to trader
        ytToken.mint(trader, 1_000e18);

        vm.prank(trader);
        IERC20(address(ytToken)).approve(address(amm), type(uint256).max);
    }

    // =========================================
    // Constructor Tests
    // =========================================

    function test_ConstructorSetsTokens() public view {
        assertEq(address(amm.I_M_USD()), address(cash));
        assertEq(address(amm.I_YT()), address(ytToken));
    }

    function test_SwapYTForCash_PaysExpectedAmount() public {
        uint256 ytAmount = 100e18;

        uint256 traderCashBefore = cash.balanceOf(trader);

        vm.prank(trader);
        uint256 cashReceived = amm.swapYTforCash(ytAmount);

        // MockAMM uses YIELD_PRICE = 0.05 ether, so 100 YT => 5 cash.
        assertEq(cashReceived, 5e18);
        assertEq(cash.balanceOf(trader), traderCashBefore + 5e18);
    }

    function test_YieldPriceIsCorrect() public view {
        assertEq(amm.YIELD_PRICE(), 0.05 ether);
    }

    // =========================================
    // Swap Tests
    // =========================================

    function test_SwapYTForCash() public {
        uint256 ytAmount = 1000e18;
        uint256 expectedCash = (ytAmount * amm.YIELD_PRICE()) / 1e18;
        
        // Mint YT to trader
        ytToken.mint(trader, ytAmount);
        
        // Trader approves AMM
        vm.startPrank(trader);
        ytToken.approve(address(amm), ytAmount);
        
        // Execute swap
        uint256 cashReceived = amm.swapYTforCash(ytAmount);
        vm.stopPrank();
        
        assertEq(cashReceived, expectedCash);
        assertEq(cashReceived, 50e18); // 1000 * 0.05 = 50
        assertEq(cash.balanceOf(trader), expectedCash);
        assertEq(ytToken.balanceOf(address(amm)), ytAmount);
    }

    function test_SwapCalculatesCorrectPrice() public {
        // 100 YT should give 5 cash (5%)
        uint256 ytAmount = 100e18;
        ytToken.mint(trader, ytAmount);
        
        vm.startPrank(trader);
        ytToken.approve(address(amm), ytAmount);
        uint256 cashReceived = amm.swapYTforCash(ytAmount);
        vm.stopPrank();
        
        assertEq(cashReceived, 5e18);
    }

    function test_MultipleSwaps() public {
        address trader2 = makeAddr("trader2");
        
        // First swap
        ytToken.mint(trader, 100e18);
        vm.startPrank(trader);
        ytToken.approve(address(amm), 100e18);
        uint256 cash1 = amm.swapYTforCash(100e18);
        vm.stopPrank();
        
        // Second swap
        ytToken.mint(trader2, 200e18);
        vm.startPrank(trader2);
        ytToken.approve(address(amm), 200e18);
        uint256 cash2 = amm.swapYTforCash(200e18);
        vm.stopPrank();
        
        assertEq(cash1, 5e18);
        assertEq(cash2, 10e18);
        assertEq(ytToken.balanceOf(address(amm)), 300e18);
    }

    function test_RevertWhen_InsufficientLiquidity() public {
        // Drain AMM liquidity
        uint256 ammBalance = cash.balanceOf(address(amm));
        
        // Try to swap more YT than AMM can pay for
        // Need way more than what AMM can afford
        uint256 ytAmount = (ammBalance * 1e18) / amm.YIELD_PRICE() + 1000e18;
        ytToken.mint(trader, ytAmount);
        
        vm.startPrank(trader);
        ytToken.approve(address(amm), ytAmount);
        
        vm.expectRevert("MockAMM: Out of Liquidity");
        amm.swapYTforCash(ytAmount);
        vm.stopPrank();
    }

    function test_RevertWhen_NoApproval() public {
        address noApprovalTrader = makeAddr("noApprovalTrader");
        ytToken.mint(noApprovalTrader, 100e18);

        vm.prank(noApprovalTrader);
        vm.expectRevert();
        amm.swapYTforCash(100e18);
    }

    function test_RevertWhen_InsufficientYTBalance() public {
        address lowBalanceTrader = makeAddr("lowBalanceTrader");
        ytToken.mint(lowBalanceTrader, 50e18);

        vm.startPrank(lowBalanceTrader);
        ytToken.approve(address(amm), 100e18);
        
        vm.expectRevert();
        amm.swapYTforCash(100e18);
        vm.stopPrank();
    }

    function testFuzz_SwapYTForCash(uint256 ytAmount) public {
        vm.assume(ytAmount > 0 && ytAmount < 1_000_000e18);
        
        uint256 expectedCash = (ytAmount * amm.YIELD_PRICE()) / 1e18;
        vm.assume(expectedCash <= cash.balanceOf(address(amm)));
        
        ytToken.mint(trader, ytAmount);
        
        vm.startPrank(trader);
        ytToken.approve(address(amm), ytAmount);
        uint256 cashReceived = amm.swapYTforCash(ytAmount);
        vm.stopPrank();
        
        assertEq(cashReceived, expectedCash);
        assertEq(cash.balanceOf(trader), expectedCash);
    }

    // =========================================
    // Edge Case Tests
    // =========================================

    function test_SwapVerySmallAmount() public {
        uint256 ytAmount = 1; // 1 wei
        ytToken.mint(trader, ytAmount);
        
        vm.startPrank(trader);
        ytToken.approve(address(amm), ytAmount);
        uint256 cashReceived = amm.swapYTforCash(ytAmount);
        vm.stopPrank();
        
        // With 5% yield, 1 wei gives 0 due to rounding
        assertEq(cashReceived, 0);
    }

    function test_SwapLargeAmount() public {
        uint256 ytAmount = 10_000e18;
        uint256 expectedCash = 500e18; // 10000 * 0.05
        
        // Ensure AMM has enough liquidity
        assertTrue(cash.balanceOf(address(amm)) >= expectedCash);
        
        ytToken.mint(trader, ytAmount);
        
        vm.startPrank(trader);
        ytToken.approve(address(amm), ytAmount);
        uint256 cashReceived = amm.swapYTforCash(ytAmount);
        vm.stopPrank();
        
        assertEq(cashReceived, expectedCash);
    }

    function test_AMMAccumulatesYT() public {
        uint256 totalYT = 0;
        
        for (uint i = 0; i < 5; i++) {
            address newTrader = makeAddr(string(abi.encodePacked("trader", i)));
            uint256 ytAmount = 100e18;
            totalYT += ytAmount;
            
            ytToken.mint(newTrader, ytAmount);
            vm.startPrank(newTrader);
            ytToken.approve(address(amm), ytAmount);
            amm.swapYTforCash(ytAmount);
            vm.stopPrank();
        }
        
        assertEq(ytToken.balanceOf(address(amm)), totalYT);
    }
}
