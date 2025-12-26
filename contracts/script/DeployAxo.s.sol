// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {AxoVault} from "src/AxoVault.sol";
import {MockMUSD} from "src/mocks/MockMUSD.sol";
import {AxoToken} from "src/AxoToken.sol";
import {AxoBatchAuction} from "src/AxoBatchAuction.sol";

contract DeployScript is Script {
    // --- Deployment Constants ---
    uint256 private constant AUCTION_INITIAL_CASH = 100_000; // 100k tokens
    uint256 private constant DECIMALS_MULTIPLIER = 1e18;
    uint256 private constant INITIAL_SUPPLY = 10_000_000;
    uint256 private constant TERM_SECONDS = 90 days;

    function run() external {
        vm.startBroadcast();
        // --- Tokens ---
        AxoToken pmUSD = new AxoToken("Principal Mantle USD", "pmUSD",address(msg.sender));
        AxoToken ymUSD = new AxoToken("Yield Mantle USD", "ymUSD",address(msg.sender));
        
        // --- SYSTEM 1: mUSD ---
        MockMUSD musd = new MockMUSD(INITIAL_SUPPLY,"Mantle USD", "mUSD");
        AxoBatchAuction auctionUSD = new AxoBatchAuction(address(musd), address(ymUSD));
        AxoVault vaultUSD = new AxoVault(
            address(musd),
            address(auctionUSD),
            address(pmUSD),
            address(ymUSD),
            block.timestamp + TERM_SECONDS
        );
        
        // Transfer token ownership to vault so it can mint/burn
        pmUSD.transferOwnership(address(vaultUSD));
        ymUSD.transferOwnership(address(vaultUSD));
        
        // Seed auction with some cash so deposits can clear in local testing
        // NOTE: In prod this would be external bids, not protocol-funded.
        musd.approve(address(auctionUSD), AUCTION_INITIAL_CASH * DECIMALS_MULTIPLIER);
        auctionUSD.depositCash(AUCTION_INITIAL_CASH * DECIMALS_MULTIPLIER);

        // --- Logs ---
        console.log("-----------------------------------");
        console.log("PT Token: ", address(pmUSD));
        console.log("YT Token: ", address(ymUSD));
        console.log("-----------------------------------");
        console.log("mUSD Asset: ", address(musd));
        console.log("mUSD Auction: ", address(auctionUSD));
        console.log("mUSD Vault: ", address(vaultUSD));
        console.log("-----------------------------------");

        vm.stopBroadcast();
    }
}