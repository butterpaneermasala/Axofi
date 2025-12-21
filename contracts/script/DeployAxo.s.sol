// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../src/AxoVault.sol";
import "../src/mocks/MockMUSD.sol";
import "../src/mocks/MockAMM.sol";
import {AxoToken} from "../src/AxoToken.sol";

contract DeployScript is Script {
    // --- Deployment Constants ---
    uint256 private constant AMM_INITIAL_LIQUIDITY = 100_000; // 100k tokens
    uint256 private constant DECIMALS_MULTIPLIER = 1e18;
    uint256 private constant INITIAL_SUPPLY = 10_000_000;

    function run() external {
        vm.startBroadcast();
        // --- Tokens ---
        AxoToken pmUSD = new AxoToken("Principal Mantle USD", "pmUSD",address(msg.sender));
        AxoToken ymUSD = new AxoToken("Yield Mantle USD", "ymUSD",address(msg.sender));
        
        // --- SYSTEM 1: mUSD ---
        MockMUSD musd = new MockMUSD(INITIAL_SUPPLY,"Mantle USD", "mUSD");
        MockAMM ammUSD = new MockAMM(address(musd), address(ymUSD));
        AxoVault vaultUSD = new AxoVault(address(musd), address(ammUSD), address(pmUSD), address(ymUSD));
        
        // Transfer token ownership to vault so it can mint/burn
        pmUSD.transferOwnership(address(vaultUSD));
        ymUSD.transferOwnership(address(vaultUSD));
        
        // Fund AMM with initial liquidity
        musd.faucet(address(ammUSD), AMM_INITIAL_LIQUIDITY * DECIMALS_MULTIPLIER);

        // --- SYSTEM 2: mETH ---
        MockMUSD meth = new MockMUSD("Mantle Staked ETH", "mETH");
        MockAMM ammETH = new MockAMM(address(meth), address(ymUSD));
        AxoVault vaultETH = new AxoVault(address(meth), address(ammETH), address(pmUSD), address(ymUSD));
        
        // Fund AMM with initial liquidity
        meth.faucet(address(ammETH), AMM_INITIAL_LIQUIDITY * DECIMALS_MULTIPLIER);

        // --- Logs ---
        console.log("-----------------------------------");
        console.log("PT Token: ", address(pmUSD));
        console.log("YT Token: ", address(ymUSD));
        console.log("-----------------------------------");
        console.log("mUSD Asset: ", address(musd));
        console.log("mUSD AMM: ", address(ammUSD));
        console.log("mUSD Vault: ", address(vaultUSD));
        console.log("-----------------------------------");
        console.log("mETH Asset: ", address(meth));
        console.log("mETH Vault: ", address(vaultETH));
        console.log("-----------------------------------");

        vm.stopBroadcast();
    }
}