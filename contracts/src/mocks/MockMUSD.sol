// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
/**
 * @title Mock mUSD token inspired by https://github.com/code-423n4/2023-09-ondo/blob/main/contracts/usdy/rUSDYFactory.sol
 * @author x@satyaorz
 * @notice to mock the logic of mUSD to simulate same type of behaviour
 */
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol"; // ownable also imports context btw

/**
 * @title Interest-bearing ERC20-like token for mUSD(rUSDY).
 *
 * mUSD balances are dynamic and represent the holder's share of the underlying USDY
 * controlled by the protocol. To calculate each account's balance, we do
 *
 *   shares[account] * usdyPrice
 *
 * For example, assume that we have:
 *
 *   usdyPrice = 1.05
 *   sharesOf(user1) -> 100
 *   sharesOf(user2) -> 400
 *
 * Therefore:
 *
 *   balanceOf(user1) -> 105 tokens which corresponds 105 rUSDY
 *   balanceOf(user2) -> 420 tokens which corresponds 420 rUSDY
 *
 * Since balances of all token holders change when the price of USDY changes, this
 * token cannot fully implement ERC20 standard: it only emits `Transfer` events
 * upon explicit transfer between holders. In contrast, when total amount of pooled
 * Cash increases, no `Transfer` events are generated: doing so would require emitting
 * an event for each token holder and thus running an unbounded loop.
 * 
 * *In other words
 * mUSD's yield is depended on USDY, and USDY is an accumulating token.
 * While mUSD's price stays at $1.00, at a fixed 5% AYP USDY's price might go from $1.00 to $1.05 after one year
 * so initially if a user has 100 mMUSD at fixed 5% AYP, after a year the user should have 105 mUSD tokens 
 * the price of USDY's goes up we get more tokens, if it goes down we get less tokens
 * 
 * @notice the logic for rebasing is implimented in the contarct mocks/MockUSDEngine.sol
 */


interface IRebaseToken {
    function rebase(int256 supplyDelta) external; 
    function totalSupply() external view returns(uint256);
    function tokenDecimals() external view returns (uint8);
    function transfer(address to, uint256 value) external returns (bool);
}

// aderyn-fp-next-line(centralization-risk)
contract MockMUSD is Ownable {

    // --- errors ---
    error MockMUSD__initialSupplyMustNotBeZero();

    // --- events ---
    event Transfer(address from, address to, uint256 amount);
    event Approval(address from, address to, uint256 amount);

    // --- public variables ---
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    /**
     * Fragments = external token units, what wallet sees/ERC20 balance and what functions like totalSupply and balanceOf returns
     * Gons = interal, FIXED atomic shares that does not change on rebase. 
     */
    // --- private varibles ---
    uint256 private _totalSupply;        // visible supply (fragments) // Current external total supply // adjusted on rebase
    uint256 private _gonsPerFragment;    // scaling factor 
    uint256 private TOTAL_GONS;
    // address private immutable I_OWNER;

    // --- storage varibales ---
    mapping(address => mapping(address => uint256)) private s_allowances;

    mapping(address user => uint256 totalShare) private s_gonsBalances;

    address public rebaseController; // e.g., RebaseEngine

    // --- modifier ---
    modifier onlyRebaseController() {
        require(_msgSender() == rebaseController, "not controller");
        _;
    }
    
    constructor(uint256 initialSupply, string memory _name, string memory _symbol) Ownable(_msgSender()) {
        if(initialSupply < 1) {
            revert MockMUSD__initialSupplyMustNotBeZero();
        }
        name = _name;
        symbol = _symbol;
        _totalSupply = initialSupply;
        // set TOTAL_GONS as max multiple of initialSupply
        TOTAL_GONS = type(uint256).max - (type(uint256).max % initialSupply); // 16 - 16%7 = 14, 14%7 = 0
        _gonsPerFragment = TOTAL_GONS / _totalSupply;
        s_gonsBalances[_msgSender()] = TOTAL_GONS; // owner holds initial
        // I_OWNER = _msgSender();
    }
    
    function totalSupply() public view returns (uint256) { 
        return _totalSupply; 
    }

    function balanceOf(address who) public view returns (uint256) {
        return s_gonsBalances[who] / _gonsPerFragment;
    }


    /**
     * @notice called by a token holder to move their tokens
     * @param to the address they want to move their tokens to
     * @param value the amount of tokens they want to move
     */
    function transfer(address to, uint256 value) public returns (bool) {
        uint256 gonValue = value * _gonsPerFragment;
        
        // Update Gons
        s_gonsBalances[_msgSender()] -= gonValue;
        s_gonsBalances[to] += gonValue;
        
        // REQUIRED: Emit the Transfer event so Wallet/blockexplorer/Metamask sees it
        emit Transfer(_msgSender(), to, value); 
        return true;
    }


    /**
     * @notice called by token holder to set an allowance for `spender`
     * @notice internal function, only called by `transferFrom`
     * @param owner address of the owner
     * @param spender address of the spender they want to allow their tokens to
     */
    function allowance(address owner, address spender) internal view returns (uint256) {
        return s_allowances[owner][spender];
    }

    /**
     * @notice called by users who want to set a spender for their tokens
     * @param spender the spender
     * @param value amount of tokens the users want to allow
     */

    function approve(address spender, uint256 value) public returns (bool) {
        s_allowances[_msgSender()][spender] = value;
        emit Approval(_msgSender(), spender, value);
        return true;
    }


    /**
     * @notice this function allows the spender to spend/move the tokens
     * @param from this is the owner address
     * @param to the target/receiver address the spender wants the token to transfer
     * @param value the amount of tokens that is being moved
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        uint256 currentAllowance = s_allowances[from][_msgSender()];
        require(currentAllowance >= value, "ERC20: transfer amount exceeds allowance");
        
        unchecked {
            s_allowances[from][_msgSender()] = currentAllowance - value;
        }

        uint256 gonValue = value * _gonsPerFragment;
        s_gonsBalances[from] -= gonValue;
        s_gonsBalances[to] += gonValue;

        emit Transfer(from, to, value);
        return true;
    }

    function setRebaseController(address controller) external onlyOwner {
        rebaseController = controller;
    }

    function rebase(int256 supplyDelta) external onlyRebaseController {
        if (supplyDelta == 0) {
            // emit event if needed
            return;
        }
        if (supplyDelta < 0) {
            uint256 decrease = uint256(-supplyDelta);
            _totalSupply = _totalSupply > decrease ? _totalSupply - decrease : 1;
        } else {
            _totalSupply = _totalSupply + uint256(supplyDelta);
        }
        _gonsPerFragment = TOTAL_GONS / _totalSupply;
    }

    function tokenDecimals() external view returns(uint8) {
        return decimals;
    }

}


/**
 * Algorithmic rebased stablecoin system
 * concept: how can we rebase users tokens without looping through all token holders?
 * In a standard ERC20 token, the balance only increases or decreases only where we interact with the token, like transer
 * but in this type of token the the number of tokens in users wallet changes by the protocol contracting or expanding the total supply
 * How does it work?
 * gons vs fragments
 * To change everyones balance without spending ALOT of gas and looping through every user in the protocol, the contracts uses the mathematical mechanism called `gon`
 * gonBalance() -> Internal Balance : this can be userstood as the user's share in the network, this never changes due to the reabse nature
 * balanceOf() -> External Balance : This is the the amount of rebased token the user has, which they see in their wallet
 * Balance = InternalGons / GonsPerFragment
 * How does Rebasing happens? 
 * When the supply needs to change it does not touch the users* but changes the GonsPerFragment
 * -> If supply increases the _gonsPerFragment gets smaller -> users balance go up
 * -> If supply decreases the _gonsPerFragment gets larger -> users balance go down
 * Example:
 * -> price of X depends on Y, say price of Y is $1 and we have 100 X tokens
 * -> price of Y pumps to $1.05,
 * DesiredSupply = TotalSupply * (CurrentPrice/TargetPrice)
 * prtocol will change the totalsupply and the user who had 100 X now will have 105 X
 */