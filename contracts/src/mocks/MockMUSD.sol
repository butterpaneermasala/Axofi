// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// aderyn-fp-next-line(centralization-risk)
contract MockMUSD is ERC20, Ownable {
    // 1. Setup: Mint 1 Million to deployer immediately
    uint256 constant MOCKFAUCETSUPPY = 1e6;
    uint256 constant PRECISION = 1e18;

    constructor(string memory _name, string memory _symbol) 
        ERC20(_name, _symbol) 
        Ownable(msg.sender) 
    {
        _mint(msg.sender, MOCKFAUCETSUPPY * PRECISION);
    }

    // 2. The "Free Money" Button for your Frontend
    // Call this when the user clicks "Get Test Tokens"
    function faucet(address to, uint256 amount) external {                          
        _mint(to, amount);
    }

    // 3. The "Time Travel" Button for your Demo
    // Call this to simulate interest accumulating in the Vault
    // (In real life, this happens automatically via Rebase)
    function simulateYield(address vault, uint256 amount) external onlyOwner {
        _mint(vault, amount);
    }
}