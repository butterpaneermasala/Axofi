// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// import "forge-std/Test.sol";
// import "../src/AxoVault.sol";
// import "../src/AxoToken.sol";
// import "../src/mocks/MockMUSD.sol";
// import "../src/mocks/MockAMM.sol";

// contract AxoVaultTest is Test {
//     AxoVault public vault;
//     AxoToken public ptToken;
//     AxoToken public ytToken;
//     MockMUSD public mUSD;
//     MockAMM public amm;
    
//     address public owner;
//     address public user1;
//     address public user2;

//     event Deposited(address indexed user, uint256 assetsDeposited, uint256 ptReceived);
//     event Redeemed(address indexed user, uint256 ptBurned, uint256 assetsReturned);
//     event YieldSold(uint256 ytAmount, uint256 cashReceived);
//     event EmergencyWithdraw(address indexed owner, address indexed token, uint256 amount);

//     function setUp() public {
//         owner = address(this);
//         user1 = makeAddr("user1");
//         user2 = makeAddr("user2");
        
//         // Deploy tokens
//         mUSD = new MockMUSD("Mantle USD", "mUSD");
//         ptToken = new AxoToken("Principal Token", "PT", owner);
//         ytToken = new AxoToken("Yield Token", "YT", owner);
        
//         // Deploy AMM and fund it
//         amm = new MockAMM(address(mUSD), address(ytToken));
//         mUSD.faucet(address(amm), 100_000e18);
        
//         // Deploy Vault
//         vault = new AxoVault(address(mUSD), address(amm), address(ptToken), address(ytToken));
        
//         // Transfer token ownership to vault
//         ptToken.transferOwnership(address(vault));
//         ytToken.transferOwnership(address(vault));
        
//         // Give users some mUSD
//         mUSD.faucet(user1, 10_000e18);
//         mUSD.faucet(user2, 10_000e18);
//     }

//     // =========================================
//     // Constructor Tests
//     // =========================================

//     function test_ConstructorSetsTokens() public view {
//         assertEq(address(vault.I_ASSET()), address(mUSD));
//         assertEq(address(vault.I_PT()), address(ptToken));
//         assertEq(address(vault.I_YT()), address(ytToken));
//         assertEq(address(vault.I_AMM()), address(amm));
//     }

//     function test_ConstructorSetsOwner() public view {
//         assertEq(vault.owner(), owner);
//     }

//     function test_InitialStateIsZero() public view {
//         assertEq(vault.totalDeposits(), 0);
//         assertEq(vault.totalYieldSold(), 0);
//     }

//     // =========================================
//     // Deposit Tests
//     // =========================================

//     function test_DepositFixed() public {
//         uint256 depositAmount = 1000e18;
//         uint256 expectedYieldCash = (depositAmount * amm.YIELD_PRICE()) / 1e18;
//         uint256 expectedTotalPT = depositAmount + expectedYieldCash;
        
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), depositAmount);
        
//         vm.expectEmit(true, false, false, true);
//         emit YieldSold(depositAmount, expectedYieldCash);
        
//         vm.expectEmit(true, false, false, true);
//         emit Deposited(user1, depositAmount, expectedTotalPT);
        
//         vault.depositFixed(depositAmount, 0);
//         vm.stopPrank();
        
//         assertEq(ptToken.balanceOf(user1), expectedTotalPT);
//         // Vault has original deposit PLUS cash from selling YT
//         assertEq(mUSD.balanceOf(address(vault)), depositAmount + expectedYieldCash);
//         assertEq(vault.totalDeposits(), depositAmount);
//         assertEq(vault.totalYieldSold(), expectedYieldCash);
//     }

//     function test_DepositCalculatesCorrectYield() public {
//         uint256 depositAmount = 1000e18;
        
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), depositAmount);
//         vault.depositFixed(depositAmount, 0);
//         vm.stopPrank();
        
//         // User should receive 1000 + 50 (5% yield) = 1050 PT
//         assertEq(ptToken.balanceOf(user1), 1050e18);
//     }

//     function test_MultipleDeposits() public {
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), 2000e18);
//         vault.depositFixed(1000e18, 0);
//         vault.depositFixed(1000e18, 0);
//         vm.stopPrank();
        
//         // 2 deposits of 1000 with 5% yield each = 2100 PT
//         assertEq(ptToken.balanceOf(user1), 2100e18);
//         assertEq(vault.totalDeposits(), 2000e18);
//     }

//     function test_DepositFromMultipleUsers() public {
//         // User1 deposits
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), 1000e18);
//         vault.depositFixed(1000e18, 0);
//         vm.stopPrank();
        
//         // User2 deposits
//         vm.startPrank(user2);
//         mUSD.approve(address(vault), 2000e18);
//         vault.depositFixed(2000e18, 0);
//         vm.stopPrank();
        
//         assertEq(ptToken.balanceOf(user1), 1050e18);
//         assertEq(ptToken.balanceOf(user2), 2100e18);
//         assertEq(vault.totalDeposits(), 3000e18);
//     }

//     function test_DepositWithSlippageProtection() public {
//         uint256 depositAmount = 1000e18;
//         uint256 minPtOut = 1040e18; // Expecting at least 1040 PT
        
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), depositAmount);
//         vault.depositFixed(depositAmount, minPtOut);
//         vm.stopPrank();
        
//         assertEq(ptToken.balanceOf(user1), 1050e18);
//     }

//     function test_RevertWhen_DepositAmountZero() public {
//         vm.prank(user1);
//         vm.expectRevert(AxoVault.AxoVault__AmountZero.selector);
//         vault.depositFixed(0, 0);
//     }

//     function test_RevertWhen_DepositWithoutApproval() public {
//         vm.prank(user1);
//         vm.expectRevert();
//         vault.depositFixed(1000e18, 0);
//     }

//     function test_RevertWhen_SlippageTooHigh() public {
//         uint256 depositAmount = 1000e18;
//         uint256 minPtOut = 2000e18; // Unrealistic expectation
        
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), depositAmount);
        
//         vm.expectRevert();
//         vault.depositFixed(depositAmount, minPtOut);
//         vm.stopPrank();
//     }

//     function test_RevertWhen_DepositWhilePaused() public {
//         vault.pause();
        
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), 1000e18);
        
//         vm.expectRevert();
//         vault.depositFixed(1000e18, 0);
//         vm.stopPrank();
//     }

//     function testFuzz_Deposit(uint256 amount) public {
//         vm.assume(amount > 0 && amount <= 10_000e18);
        
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), amount);
//         vault.depositFixed(amount, 0);
//         vm.stopPrank();
        
//         uint256 expectedYield = (amount * amm.YIELD_PRICE()) / 1e18;
//         assertEq(ptToken.balanceOf(user1), amount + expectedYield);
//     }

//     // =========================================
//     // Redeem Tests
//     // =========================================

//     function test_Redeem() public {
//         // First deposit
//         uint256 depositAmount = 1000e18;
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), depositAmount);
//         vault.depositFixed(depositAmount, 0);
        
//         // Then redeem
//         uint256 ptBalance = ptToken.balanceOf(user1);
//         uint256 redeemAmount = 500e18;
        
//         vm.expectEmit(true, false, false, true);
//         emit Redeemed(user1, redeemAmount, redeemAmount);
        
//         vault.redeem(redeemAmount);
//         vm.stopPrank();
        
//         assertEq(ptToken.balanceOf(user1), ptBalance - redeemAmount);
//         assertEq(mUSD.balanceOf(user1), 9000e18 + redeemAmount); // 10000 - 1000 + 500
//         assertEq(vault.totalDeposits(), depositAmount - redeemAmount);
//     }

//     function test_RedeemFullBalance() public {
//         uint256 depositAmount = 1000e18;
        
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), depositAmount);
//         vault.depositFixed(depositAmount, 0);
        
//         uint256 ptBalance = ptToken.balanceOf(user1); // 1050 PT
//         // Vault has 1050 mUSD (1000 deposited + 50 from YT sale)
//         // So user CAN redeem all 1050 PT
//         vault.redeem(ptBalance);
//         vm.stopPrank();
        
//         assertEq(ptToken.balanceOf(user1), 0);
//         // User started with 10k, deposited 1k, now redeems 1050
//         assertEq(mUSD.balanceOf(user1), 10_050e18);
//     }

//     function test_RevertWhen_RedeemAmountZero() public {
//         vm.prank(user1);
//         vm.expectRevert(AxoVault.AxoVault__AmountZero.selector);
//         vault.redeem(0);
//     }

//     function test_RevertWhen_RedeemInsufficientLiquidity() public {
//         // User has PT but vault has no mUSD
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), 1000e18);
//         vault.depositFixed(1000e18, 0);
//         vm.stopPrank();
        
//         // Drain vault
//         vm.prank(owner);
//         vault.emergencyWithdraw(address(mUSD), mUSD.balanceOf(address(vault)));
        
//         vm.prank(user1);
//         vm.expectRevert(AxoVault.AxoVault__InsufficientLiquidity.selector);
//         vault.redeem(100e18);
//     }

//     function test_RevertWhen_RedeemWhilePaused() public {
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), 1000e18);
//         vault.depositFixed(1000e18, 0);
//         vm.stopPrank();
        
//         vault.pause();
        
//         vm.prank(user1);
//         vm.expectRevert();
//         vault.redeem(100e18);
//     }

//     function testFuzz_Redeem(uint256 depositAmount, uint256 redeemAmount) public {
//         vm.assume(depositAmount > 0 && depositAmount <= 10_000e18);
//         vm.assume(redeemAmount > 0 && redeemAmount <= depositAmount);
        
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), depositAmount);
//         vault.depositFixed(depositAmount, 0);
//         vault.redeem(redeemAmount);
//         vm.stopPrank();
        
//         assertEq(vault.totalDeposits(), depositAmount - redeemAmount);
//     }

//     // =========================================
//     // Pause/Unpause Tests
//     // =========================================

//     function test_PauseContract() public {
//         vault.pause();
//         assertTrue(vault.paused());
//     }

//     function test_UnpauseContract() public {
//         vault.pause();
//         vault.unpause();
//         assertFalse(vault.paused());
//     }

//     function test_RevertWhen_PauseByNonOwner() public {
//         vm.prank(user1);
//         vm.expectRevert();
//         vault.pause();
//     }

//     function test_RevertWhen_UnpauseByNonOwner() public {
//         vault.pause();
        
//         vm.prank(user1);
//         vm.expectRevert();
//         vault.unpause();
//     }

//     // =========================================
//     // Emergency Withdraw Tests
//     // =========================================

//     function test_EmergencyWithdraw() public {
//         // Deposit some mUSD
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), 1000e18);
//         vault.depositFixed(1000e18, 0);
//         vm.stopPrank();
        
//         uint256 vaultBalance = mUSD.balanceOf(address(vault));
//         uint256 ownerBalanceBefore = mUSD.balanceOf(owner);
        
//         vm.expectEmit(true, true, false, true);
//         emit EmergencyWithdraw(owner, address(mUSD), vaultBalance);
        
//         vault.emergencyWithdraw(address(mUSD), vaultBalance);
        
//         assertEq(mUSD.balanceOf(owner), ownerBalanceBefore + vaultBalance);
//         assertEq(mUSD.balanceOf(address(vault)), 0);
//     }

//     function test_RevertWhen_EmergencyWithdrawByNonOwner() public {
//         vm.prank(user1);
//         vm.expectRevert();
//         vault.emergencyWithdraw(address(mUSD), 100e18);
//     }

//     // =========================================
//     // View Function Tests
//     // =========================================

//     function test_GetTotalValueLocked() public {
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), 1000e18);
//         vault.depositFixed(1000e18, 0);
//         vm.stopPrank();
        
//         // TVL = deposited 1000 + 50 from selling YT
//         assertEq(vault.getTotalValueLocked(), 1050e18);
//     }

//     function test_GetUserPTBalance() public {
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), 1000e18);
//         vault.depositFixed(1000e18, 0);
//         vm.stopPrank();
        
//         assertEq(vault.getUserPTBalance(user1), 1050e18);
//     }

//     function test_GetUserYTBalance() public view {
//         // Users don't hold YT directly, vault sells it
//         assertEq(vault.getUserYTBalance(user1), 0);
//     }

//     // =========================================
//     // Reentrancy Protection Tests
//     // =========================================

//     function test_DepositIsProtectedFromReentrancy() public {
//         // This is implicitly tested by the nonReentrant modifier
//         // Foundry will catch reentrancy attempts
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), 1000e18);
//         vault.depositFixed(1000e18, 0);
//         vm.stopPrank();
//     }

//     // =========================================
//     // Integration Tests
//     // =========================================

//     function test_FullDepositRedeemCycle() public {
//         uint256 depositAmount = 1000e18;
        
//         // Deposit
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), depositAmount);
//         vault.depositFixed(depositAmount, 0);
        
//         // Check balances
//         uint256 ptBalance = ptToken.balanceOf(user1);
//         assertEq(ptBalance, 1050e18);
        
//         // Redeem original amount
//         vault.redeem(depositAmount);
//         vm.stopPrank();
        
//         // User should have original mUSD back
//         assertEq(mUSD.balanceOf(user1), 10_000e18);
//         // User still has 50 PT (the yield portion)
//         assertEq(ptToken.balanceOf(user1), 50e18);
//     }

//     function test_MultipleUsersCanInteractConcurrently() public {
//         // User1 deposits
//         vm.startPrank(user1);
//         mUSD.approve(address(vault), 1000e18);
//         vault.depositFixed(1000e18, 0);
//         vm.stopPrank();
        
//         // User2 deposits
//         vm.startPrank(user2);
//         mUSD.approve(address(vault), 500e18);
//         vault.depositFixed(500e18, 0);
//         vm.stopPrank();
        
//         // User1 redeems
//         vm.prank(user1);
//         vault.redeem(500e18);
        
//         // Check final state
//         assertEq(vault.totalDeposits(), 1000e18);
//         assertEq(ptToken.balanceOf(user1), 550e18);
//         assertEq(ptToken.balanceOf(user2), 525e18);
//     }
// }
