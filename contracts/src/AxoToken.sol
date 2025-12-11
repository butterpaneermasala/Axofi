// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
// This the token contract of the protocol, we that mints and burns the tokens(PMUSD and YMUSD) 

import { ERC20Burnable, ERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";



/**
 * @title AxoTonken
 * @author satyaorz
 * @notice This is the Token Contract of the protocol, that mints and burn the ERC20 tokens (PMUSD and YMUSD). 
 * @notice PMUSD is the principal token and YMUSD is the yield token
 */
// aderyn-fp-next-line(centralization-risk)
contract AxoToken is ERC20Burnable, Ownable {
    error AxoToken__NotZeroAddress();
    error AxoToken__AmountMustBeMoreThanZero();
    error AxoToken__BurnAmountExceedsBalance();

    // We pass Name, Symbol, and Owner dynamically
    constructor(
        string memory name, 
        string memory symbol, 
        address initialOwner
    ) 
        ERC20(name, symbol) 
        Ownable(initialOwner) 
    {}


    /**
     * @param _to the address we want to mint token to
     * @param _amount the amount of tokens to mint
     */
    // aderyn-ignore-next-line(centralization-risk)
    function mint(address _to, uint256 _amount) external onlyOwner returns(bool) {
        if (_to == address(0)) {
            revert AxoToken__NotZeroAddress();
        }

        if (_amount <= 0) {
            revert AxoToken__AmountMustBeMoreThanZero();
        }

        _mint(_to, _amount);
        return true;
    }


    /**
     * @param _amount the amount of tokens to burn
     */
    // aderyn-ignore-next-line(centralization-risk)
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert AxoToken__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert AxoToken__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }
}