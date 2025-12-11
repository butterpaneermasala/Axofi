// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/AxoVault.sol";
import "../src/AxoToken.sol";
import "../src/mocks/MockMUSD.sol";
import "../src/mocks/MockAMM.sol";

/**
 * @title Integration Tests
 * @notice End-to-end testing of the entire Axofi protocol
 */
contract IntegrationTest is Test {
    AxoVault public vault;
    AxoToken public ptToken;
    AxoToken public ytToken;
    MockMUSD public mUSD;
    MockAMM public amm;
    
    address public owner;
    address public alice;
    address public bob;
    address public charlie;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        
        // Deploy full protocol
        mUSD = new MockMUSD("Mantle USD", "mUSD");
        ptToken = new AxoToken("Principal Token", "PT", owner);
        ytToken = new AxoToken("Yield Token", "YT", owner);
        amm = new MockAMM(address(mUSD), address(ytToken));
        vault = new AxoVault(address(mUSD), address(amm), address(ptToken), address(ytToken));
        
        // Setup
        ptToken.transferOwnership(address(vault));
        ytToken.transferOwnership(address(vault));
        mUSD.faucet(address(amm), 1_000_000e18);
        
        // Give users funds
        mUSD.faucet(alice, 100_000e18);
        mUSD.faucet(bob, 50_000e18);
        mUSD.faucet(charlie, 25_000e18);
    }

    // =========================================
    // Full Protocol Flow
    // =========================================

    function test_CompleteProtocolFlow() public {
        console.log("=== Starting Complete Protocol Flow Test ===");
        
        // 1. Alice deposits 10,000 mUSD
        console.log("\n1. Alice deposits 10,000 mUSD");
        vm.startPrank(alice);
        mUSD.approve(address(vault), 10_000e18);
        vault.depositFixed(10_000e18, 0);
        vm.stopPrank();
        
        uint256 alicePT = ptToken.balanceOf(alice);
        console.log("Alice PT balance:", alicePT / 1e18);
        assertEq(alicePT, 10_500e18); // 10,000 + 500 (5% yield)
        
        // 2. Bob deposits 5,000 mUSD
        console.log("\n2. Bob deposits 5,000 mUSD");
        vm.startPrank(bob);
        mUSD.approve(address(vault), 5_000e18);
        vault.depositFixed(5_000e18, 0);
        vm.stopPrank();
        
        uint256 bobPT = ptToken.balanceOf(bob);
        console.log("Bob PT balance:", bobPT / 1e18);
        assertEq(bobPT, 5_250e18); // 5,000 + 250 (5% yield)
        
        // 3. Check vault state
        console.log("\n3. Checking vault state");
        uint256 tvl = vault.getTotalValueLocked();
        uint256 totalDeposits = vault.totalDeposits();
        uint256 totalYieldSold = vault.totalYieldSold();
        
        console.log("Total Value Locked:", tvl / 1e18);
        console.log("Total Deposits:", totalDeposits / 1e18);
        console.log("Total Yield Sold:", totalYieldSold / 1e18);
        
        assertEq(totalDeposits, 15_000e18);
        assertEq(totalYieldSold, 750e18);
        // TVL = deposits + yield sold back to vault
        assertEq(tvl, 15_750e18);
        
        // 4. Alice redeems 5,000 PT
        console.log("\n4. Alice redeems 5,000 PT");
        vm.prank(alice);
        vault.redeem(5_000e18);
        
        console.log("Alice mUSD after redeem:", mUSD.balanceOf(alice) / 1e18);
        console.log("Alice PT after redeem:", ptToken.balanceOf(alice) / 1e18);
        
        assertEq(ptToken.balanceOf(alice), 5_500e18);
        assertEq(mUSD.balanceOf(alice), 95_000e18); // 100k - 10k + 5k
        
        // 5. Charlie deposits with slippage protection
        console.log("\n5. Charlie deposits 1,000 mUSD with slippage protection");
        vm.startPrank(charlie);
        mUSD.approve(address(vault), 1_000e18);
        vault.depositFixed(1_000e18, 1_040e18); // Expects at least 1,040 PT
        vm.stopPrank();
        
        console.log("Charlie PT balance:", ptToken.balanceOf(charlie) / 1e18);
        assertEq(ptToken.balanceOf(charlie), 1_050e18);
        
        // 6. Final state check
        console.log("\n6. Final state check");
        console.log("Total PT Supply:", ptToken.totalSupply() / 1e18);
        console.log("Total Deposits:", vault.totalDeposits() / 1e18);
        console.log("Vault TVL:", vault.getTotalValueLocked() / 1e18);
        
        assertEq(vault.totalDeposits(), 11_000e18); // 15k - 5k + 1k
        // TVL = 11k deposits + 800 yield (750 from first 2 deposits + 50 from charlie - 0 since Alice redeemed before charlie deposited)
        // Actually: 10k generated 500, 5k generated 250 = 750, then -5k redeemed, then 1k generated 50 = 800 total yield
        assertEq(vault.getTotalValueLocked(), 11_800e18);
    }

    // =========================================
    // Stress Tests
    // =========================================

    function test_HighVolumeDeposits() public {
        console.log("=== High Volume Deposits Test ===");
        
        uint256 numUsers = 10;
        address[] memory users = new address[](numUsers);
        
        for (uint i = 0; i < numUsers; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            mUSD.faucet(users[i], 10_000e18);
            
            vm.startPrank(users[i]);
            mUSD.approve(address(vault), 10_000e18);
            vault.depositFixed(10_000e18, 0);
            vm.stopPrank();
        }
        
        assertEq(vault.totalDeposits(), 100_000e18);
        assertEq(vault.totalYieldSold(), 5_000e18);
        console.log("Successfully processed", numUsers, "deposits");
    }

    function test_BankRunScenario() public {
        console.log("=== Bank Run Scenario Test ===");
        
        // Multiple users deposit
        address[] memory users = new address[](5);
        for (uint i = 0; i < 5; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            mUSD.faucet(users[i], 10_000e18);
            
            vm.startPrank(users[i]);
            mUSD.approve(address(vault), 10_000e18);
            vault.depositFixed(10_000e18, 0);
            vm.stopPrank();
        }
        
        console.log("Initial TVL:", vault.getTotalValueLocked() / 1e18);
        
        // All users try to redeem at once
        for (uint i = 0; i < 5; i++) {
            vm.prank(users[i]);
            vault.redeem(10_000e18); // Only original deposit, not yield
        }
        
        console.log("Final TVL:", vault.getTotalValueLocked() / 1e18);
        // Users can only redeem 10k each, but vault has 52.5k (50k deposits + 2.5k yield)
        // So 2.5k remains in vault
        assertEq(vault.getTotalValueLocked(), 2_500e18);
        assertEq(vault.totalDeposits(), 0);
    }

    // =========================================
    // Edge Cases
    // =========================================

    function test_DepositRedeemDepositAgain() public {
        console.log("=== Deposit -> Redeem -> Deposit Again ===");
        
        // First deposit
        vm.startPrank(alice);
        mUSD.approve(address(vault), 10_000e18);
        vault.depositFixed(10_000e18, 0);
        
        uint256 pt1 = ptToken.balanceOf(alice);
        console.log("PT after first deposit:", pt1 / 1e18);
        
        // Redeem
        vault.redeem(10_000e18);
        uint256 pt2 = ptToken.balanceOf(alice);
        console.log("PT after redeem:", pt2 / 1e18);
        
        // Deposit again
        mUSD.approve(address(vault), 10_000e18);
        vault.depositFixed(10_000e18, 0);
        vm.stopPrank();
        
        uint256 pt3 = ptToken.balanceOf(alice);
        console.log("PT after second deposit:", pt3 / 1e18);
        
        // Should have original 500 + new 10,500
        assertEq(pt3, 11_000e18);
    }

    function test_ZeroYieldScenario() public {
        // If AMM has no liquidity, yield would be 0
        // Create new tokens for this vault
        AxoToken newPT = new AxoToken("New PT", "NPT", owner);
        AxoToken newYT = new AxoToken("New YT", "NYT", owner);
        
        // Deploy new AMM with no liquidity
        MockAMM newAmm = new MockAMM(address(mUSD), address(newYT));
        
        AxoVault newVault = new AxoVault(
            address(mUSD),
            address(newAmm),
            address(newPT),
            address(newYT)
        );
        
        newPT.transferOwnership(address(newVault));
        newYT.transferOwnership(address(newVault));
        
        vm.startPrank(alice);
        mUSD.approve(address(newVault), 1_000e18);
        
        // Should revert because AMM has no liquidity
        vm.expectRevert("MockAMM: Out of Liquidity");
        newVault.depositFixed(1_000e18, 0);
        vm.stopPrank();
    }

    // =========================================
    // Emergency Scenarios
    // =========================================

    function test_PauseAndResume() public {
        console.log("=== Pause and Resume Test ===");
        
        // Normal deposit
        vm.startPrank(alice);
        mUSD.approve(address(vault), 10_000e18);
        vault.depositFixed(10_000e18, 0);
        vm.stopPrank();
        
        // Pause
        vault.pause();
        console.log("Vault paused");
        
        // Try to deposit (should fail)
        vm.startPrank(bob);
        mUSD.approve(address(vault), 5_000e18);
        vm.expectRevert();
        vault.depositFixed(5_000e18, 0);
        vm.stopPrank();
        
        // Try to redeem (should fail)
        vm.prank(alice);
        vm.expectRevert();
        vault.redeem(1_000e18);
        
        // Unpause
        vault.unpause();
        console.log("Vault unpaused");
        
        // Now operations work
        vm.prank(bob);
        vault.depositFixed(5_000e18, 0);
        
        assertEq(ptToken.balanceOf(bob), 5_250e18);
    }

    function test_EmergencyRecovery() public {
        console.log("=== Emergency Recovery Test ===");
        
        // Users deposit
        vm.startPrank(alice);
        mUSD.approve(address(vault), 10_000e18);
        vault.depositFixed(10_000e18, 0);
        vm.stopPrank();
        
        // Simulate stuck tokens
        mUSD.faucet(address(vault), 5_000e18);
        
        uint256 vaultBalance = mUSD.balanceOf(address(vault));
        console.log("Vault balance before recovery:", vaultBalance / 1e18);
        
        // Emergency withdraw
        vault.emergencyWithdraw(address(mUSD), vaultBalance);
        
        console.log("Vault balance after recovery:", mUSD.balanceOf(address(vault)) / 1e18);
        assertEq(mUSD.balanceOf(address(vault)), 0);
    }

    // =========================================
    // Gas Optimization Tests
    // =========================================

    function test_GasUsageForDeposit() public {
        vm.startPrank(alice);
        mUSD.approve(address(vault), 10_000e18);
        
        uint256 gasBefore = gasleft();
        vault.depositFixed(10_000e18, 0);
        uint256 gasUsed = gasBefore - gasleft();
        
        vm.stopPrank();
        
        console.log("Gas used for deposit:", gasUsed);
        // Ensure it's reasonable (less than 500k gas)
        assertTrue(gasUsed < 500_000);
    }

    function test_GasUsageForRedeem() public {
        vm.startPrank(alice);
        mUSD.approve(address(vault), 10_000e18);
        vault.depositFixed(10_000e18, 0);
        
        uint256 gasBefore = gasleft();
        vault.redeem(5_000e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        vm.stopPrank();
        
        console.log("Gas used for redeem:", gasUsed);
        // Ensure it's reasonable (less than 200k gas)
        assertTrue(gasUsed < 200_000);
    }

    // =========================================
    // Economic Model Validation
    // =========================================

    function test_YieldRateConsistency() public {
        uint256[] memory deposits = new uint256[](5);
        deposits[0] = 1_000e18;
        deposits[1] = 5_000e18;
        deposits[2] = 10_000e18;
        deposits[3] = 50_000e18;
        deposits[4] = 100_000e18;
        
        for (uint i = 0; i < deposits.length; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            mUSD.faucet(user, deposits[i]);
            
            vm.startPrank(user);
            mUSD.approve(address(vault), deposits[i]);
            vault.depositFixed(deposits[i], 0);
            vm.stopPrank();
            
            uint256 ptBalance = ptToken.balanceOf(user);
            uint256 yield = ptBalance - deposits[i];
            uint256 yieldRate = (yield * 10000) / deposits[i]; // In basis points
            
            console.log("Deposit:", deposits[i] / 1e18, "Yield Rate (bps):", yieldRate);
            assertEq(yieldRate, 500); // Should always be 5% (500 basis points)
        }
    }

    function test_VaultAccountingAccuracy() public {
        uint256 totalDeposited = 0;
        uint256 totalRedeemed = 0;
        
        // Random deposits and redeems
        vm.startPrank(alice);
        mUSD.approve(address(vault), 50_000e18);
        vault.depositFixed(10_000e18, 0);
        totalDeposited += 10_000e18;
        
        vault.depositFixed(5_000e18, 0);
        totalDeposited += 5_000e18;
        
        vault.redeem(3_000e18);
        totalRedeemed += 3_000e18;
        
        vault.depositFixed(7_000e18, 0);
        totalDeposited += 7_000e18;
        
        vault.redeem(2_000e18);
        totalRedeemed += 2_000e18;
        vm.stopPrank();
        
        uint256 expectedDeposits = totalDeposited - totalRedeemed;
        assertEq(vault.totalDeposits(), expectedDeposits);
        console.log("Accounting is accurate. Expected:", expectedDeposits / 1e18, "Actual:", vault.totalDeposits() / 1e18);
    }
}
