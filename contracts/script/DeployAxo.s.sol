// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {AxoVault} from "src/AxoVault.sol";
import {MockMUSD} from "src/mocks/MockMUSD.sol";
import {MockAMM} from "src/mocks/MockAMM.sol";
import {MockMUSDEngine} from "src/mocks/MockMUSDEngine.sol";
import {AxoToken} from "src/AxoToken.sol";
import {MockUSDYOracle} from "src/mocks/MockUSDYOracle.sol";

contract DeployScript is Script {
    // --- Deployment Constants ---
    uint256 private constant AMM_INITIAL_LIQUIDITY = 100_000; // 100k tokens
    uint256 private constant DECIMALS_MULTIPLIER = 1e18;
    uint256 private constant TARTGET_PRICE = 1e18;
    uint256 private constant INITIAL_SUPPLY = 10_000_000;

    function run() external {
        vm.startBroadcast();
        // --- Tokens ---
        AxoToken pmUSD = new AxoToken("Principal Mantle USD", "pmUSD",address(msg.sender));
        AxoToken ymUSD = new AxoToken("Yield Mantle USD", "ymUSD",address(msg.sender));
        
        // --- SYSTEM 1: mUSD ---
        MockUSDYOracle oracle = new MockUSDYOracle(TARTGET_PRICE); 
        MockMUSD musd = new MockMUSD(INITIAL_SUPPLY,"Mantle USD", "mUSD");
        // for msudEngine it require an address mnt that is the address of the token we take and give musd in this mock flow,
        // but to test locally we can use ETH, and for that we will use address(0) for mnt address and check msg.value for sent value
        MockMUSDEngine musdEngine = new MockMUSDEngine(address(oracle), address(musd), address(0));
        MockAMM ammUSD = new MockAMM(address(musd), address(ymUSD));
        AxoVault vaultUSD = new AxoVault(address(musd), address(ammUSD), address(pmUSD), address(ymUSD));
        
        // Transfer token ownership to vault so it can mint/burn
        pmUSD.transferOwnership(address(vaultUSD));
        ymUSD.transferOwnership(address(vaultUSD));
        
        // Fund AMM with initial liquidity
        // to test we need to fund our AMM, and for that we can send the liquidity from the MockMUSDEngine
        // only for test purposes
        musdEngine.fundAmm(address(ammUSD), AMM_INITIAL_LIQUIDITY * DECIMALS_MULTIPLIER);

        // --- Logs ---
        console.log("-----------------------------------");
        console.log("PT Token: ", address(pmUSD));
        console.log("YT Token: ", address(ymUSD));
        console.log("-----------------------------------");
        console.log("mUSD Asset: ", address(musd));
        console.log("mUSD AMM: ", address(ammUSD));
        console.log("mUSD Vault: ", address(vaultUSD));
        console.log("-----------------------------------");

        vm.stopBroadcast();
    }
}