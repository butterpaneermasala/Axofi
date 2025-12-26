// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/AxoToken.sol";

contract AxoTokenTest is Test {
    AxoToken public token;
    address public owner;
    address public user1;
    address public user2;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        token = new AxoToken("Test Token", "TEST", owner);
    }

    // =========================================
    // Constructor Tests
    // =========================================

    function test_ConstructorSetsNameAndSymbol() public view {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
    }

    function test_ConstructorSetsOwner() public view {
        assertEq(token.owner(), owner);
    }

    function test_InitialSupplyIsZero() public view {
        assertEq(token.totalSupply(), 0);
    }

    // =========================================
    // Mint Tests
    // =========================================

    function test_MintSuccessfully() public {
        uint256 amount = 1000e18;
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, amount);
        
        bool success = token.mint(user1, amount);
        
        assertTrue(success);
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), amount);
    }

    function test_MintMultipleTimes() public {
        token.mint(user1, 100e18);
        token.mint(user1, 200e18);
        token.mint(user2, 50e18);
        
        assertEq(token.balanceOf(user1), 300e18);
        assertEq(token.balanceOf(user2), 50e18);
        assertEq(token.totalSupply(), 350e18);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert(AxoToken.AxoToken__NotZeroAddress.selector);
        token.mint(address(0), 100e18);
    }

    function test_RevertWhen_MintZeroAmount() public {
        vm.expectRevert(AxoToken.AxoToken__AmountMustBeMoreThanZero.selector);
        token.mint(user1, 0);
    }

    function test_RevertWhen_MintByNonOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, 100e18);
    }

    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount < type(uint256).max);
        
        token.mint(to, amount);
        assertEq(token.balanceOf(to), amount);
    }

    // =========================================
    // Burn Tests
    // =========================================

    function test_BurnSuccessfully() public {
        uint256 mintAmount = 1000e18;
        uint256 burnAmount = 300e18;
        
        token.mint(owner, mintAmount);
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(owner), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    function test_RevertWhen_BurnZeroAmount() public {
        token.mint(owner, 1000e18);
        
        vm.expectRevert(AxoToken.AxoToken__AmountMustBeMoreThanZero.selector);
        token.burn(0);
    }

    function test_RevertWhen_BurnExceedsBalance() public {
        token.mint(owner, 100e18);
        
        vm.expectRevert(AxoToken.AxoToken__BurnAmountExceedsBalance.selector);
        token.burn(101e18);
    }

    function test_RevertWhen_BurnByNonOwner() public {
        token.mint(user1, 100e18);
        
        vm.prank(user1);
        vm.expectRevert();
        token.burn(50e18);
    }

    function testFuzz_Burn(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0 && mintAmount < type(uint128).max);
        vm.assume(burnAmount > 0 && burnAmount <= mintAmount);
        
        token.mint(owner, mintAmount);
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(owner), mintAmount - burnAmount);
    }

    // =========================================
    // BurnFrom Tests
    // =========================================

    function test_BurnFromSuccessfully() public {
        uint256 amount = 1000e18;
        token.mint(user1, amount);
        
        token.burnFrom(user1, 300e18);
        
        assertEq(token.balanceOf(user1), 700e18);
        assertEq(token.totalSupply(), 700e18);
    }

    function test_BurnFromEntireBalance() public {
        uint256 amount = 1000e18;
        token.mint(user1, amount);
        
        token.burnFrom(user1, amount);
        
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.totalSupply(), 0);
    }

    function test_RevertWhen_BurnFromZeroAddress() public {
        vm.expectRevert(AxoToken.AxoToken__NotZeroAddress.selector);
        token.burnFrom(address(0), 100e18);
    }

    function test_RevertWhen_BurnFromZeroAmount() public {
        token.mint(user1, 1000e18);
        
        vm.expectRevert(AxoToken.AxoToken__AmountMustBeMoreThanZero.selector);
        token.burnFrom(user1, 0);
    }

    function test_RevertWhen_BurnFromExceedsBalance() public {
        token.mint(user1, 100e18);
        
        vm.expectRevert(AxoToken.AxoToken__BurnAmountExceedsBalance.selector);
        token.burnFrom(user1, 101e18);
    }

    function test_RevertWhen_BurnFromByNonOwner() public {
        token.mint(user1, 100e18);
        
        vm.prank(user1);
        vm.expectRevert();
        token.burnFrom(user1, 50e18);
    }

    function testFuzz_BurnFrom(address from, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(from != address(0));
        vm.assume(mintAmount > 0 && mintAmount < type(uint128).max);
        vm.assume(burnAmount > 0 && burnAmount <= mintAmount);
        
        token.mint(from, mintAmount);
        token.burnFrom(from, burnAmount);
        
        assertEq(token.balanceOf(from), mintAmount - burnAmount);
    }

    // =========================================
    // Ownership Tests
    // =========================================

    function test_TransferOwnership() public {
        token.transferOwnership(user1);
        assertEq(token.owner(), user1);
    }

    function test_OnlyNewOwnerCanMintAfterTransfer() public {
        token.transferOwnership(user1);
        
        vm.prank(user1);
        token.mint(user2, 100e18);
        
        assertEq(token.balanceOf(user2), 100e18);
    }

    function test_OldOwnerCannotMintAfterTransfer() public {
        token.transferOwnership(user1);
        
        vm.expectRevert();
        token.mint(user2, 100e18);
    }

    // =========================================
    // ERC20 Standard Tests
    // =========================================

    function test_TransferTokens() public {
        token.mint(user1, 1000e18);
        
        vm.prank(user1);
        token.transfer(user2, 300e18);
        
        assertEq(token.balanceOf(user1), 700e18);
        assertEq(token.balanceOf(user2), 300e18);
    }

    function test_ApproveAndTransferFrom() public {
        token.mint(user1, 1000e18);
        
        vm.prank(user1);
        token.approve(user2, 500e18);
        
        vm.prank(user2);
        token.transferFrom(user1, user2, 300e18);
        
        assertEq(token.balanceOf(user1), 700e18);
        assertEq(token.balanceOf(user2), 300e18);
        assertEq(token.allowance(user1, user2), 200e18);
    }
}
