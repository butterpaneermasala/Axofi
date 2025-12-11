// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../src/AxoVault.sol";
import "../src/mocks/MockMUSD.sol";
import "../src/mocks/MockAMM.sol";
import {AxoToken} from "../src/AxoToken.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();
        // --- Tokens ---
        AxoToken pmUSD = new AxoToken("Principal Mantle USD", "pmUSD",address(msg.sender));
        AxoToken ymUSD = new AxoToken("Yield Mantle USD", "ymUSD",address(msg.sender));
        
        // --- SYSTEM 1: mUSD ---
        MockMUSD musd = new MockMUSD("Mantle USD", "mUSD");
        MockAMM ammUSD = new MockAMM(address(musd));
        AxoVault vaultUSD = new AxoVault(address(musd), address(ammUSD), address(pmUSD), address(ymUSD));
        
        // Fund AMM
        musd.faucet(address(ammUSD), 100_000 * 1e18);

        // --- SYSTEM 2: mETH ---
        MockMUSD meth = new MockMUSD("Mantle Staked ETH", "mETH");
        MockAMM ammETH = new MockAMM(address(meth));
        AxoVault vaultETH = new AxoVault(address(meth), address(ammETH), address(pmUSD), address(ymUSD));
        
        // Fund AMM
        meth.faucet(address(ammETH), 100_000 * 1e18);

        // --- Logs ---
        console.log("-----------------------------------");
        console.log("mUSD Asset: ", address(musd));
        console.log("mUSD Vault: ", address(vaultUSD));
        console.log("-----------------------------------");
        console.log("mETH Asset: ", address(meth));
        console.log("mETH Vault: ", address(vaultETH));
        console.log("-----------------------------------");

        vm.stopBroadcast();
    }
}