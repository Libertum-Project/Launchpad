// SPDX-License-Identifier: UNLICENSED

// Pragma statements
// ------------------------------------
pragma solidity ^0.8.10;
pragma abicoder v2;

// Import statements
// ------------------------------------
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

// ~~~~~~~~~~~~~~ Contract ~~~~~~~~~~~~~~
//
contract Launchpad is Ownable, ReentrancyGuard, PaymentSplitter {

    IERC20 public immutable mainCurrency; //ERC20 needed to buy this projectToken
    IERC20 public immutable projectToken; //ERC20 of the project
    address public immutable projectOwner; //Owner of the listed project
    uint256 public projectPrice; //price in _mainCurrency token
    uint256 public projectSupply; //Initial supply of the project Token
    uint256 public collectedAmount; //_mainCurrency collected
    bool public isActive;
    address[] private partners;
   
    // ~~~~~~~~~~~~~~ Events ~~~~~~~~~~~~~~
    //

    event RoundFinished(uint time, uint collectedAmount);
    event TokensBought(IERC20 token, address indexed buyer, uint256 amount);
    event SupplyAdded(address from, uint256 amount);
    event SupplyReduced(address to, uint256 amount);    
    event FundsCollectedLibertum(IERC20 indexed project, address indexed Libertum, uint256 amount);
    event FundsCollectedProjectOwner(IERC20 indexed project, address indexed ProjectOwner, uint256 amount);
    event FundsCollectedLP(IERC20 indexed project, address indexed LP, uint256 amount);


    // ~~~~~~~~~~~~~~ Functions ~~~~~~~~~~~~~~
    //
    constructor(
        IERC20 mainCurrency_, 
        IERC20 projectToken_,
        address projectOwner_, 
        uint256 projectPrice_, 
        address[] memory payees_, 
        uint[] memory shares_) 
    PaymentSplitter(payees_, shares_) {
        mainCurrency = mainCurrency_;
        projectToken = projectToken_;
        projectOwner = projectOwner_;
        projectPrice = projectPrice_;
        projectSupply = 0; 
        isActive = true;
        partners = payees_;
        //Set the total sum of shares to be 100 would be better to assign percentages to the payees
        //Example: 30 shares to "X", 20 shares to "Y" and 50 shares to "P" = 100 shares(100%)
    }

    /*
        finishRound() onlyowner
        * Function to close the round for this project
        * 1. close the round, updating state variables
        * 2. call _sendFunds() and require to return true
        * 3. emit event
    */

    function finishRound() external onlyOwner {
        require(isActive, "Launchpad: Round is over.");
        isActive = false;
        collectedAmount = 0;
        require(_sendFunds(),"Launchpad: Unable to send funds.");
        emit RoundFinished(block.timestamp, collectedAmount);
    }

    /*
        _sendFunds() internal
        * 1. copy in memory the partners length
        * 2. make a for loop to send the tokens using PaymentSplitter
        * 3. return true
    */
    function _sendFunds() internal returns(bool) {
        uint partnersLength = partners.length;
        for(uint i=0;i<partnersLength;){
            PaymentSplitter.release(mainCurrency, partners[i]);
            unchecked{
                i++;
            }
        }
        return true;
    }
 


    /*
        addSupply() 
        1. FRONTEND: from_ address must approve tokens first & decimals
        2. execute transferFrom to this contract to add projectToken
        3. update projectSupply variable
        4. emit event
    */
    function addSupply(address from_, uint256 amount_) external onlyOwner {
        require(projectToken.transferFrom(from_, address(this), amount_), "Launchpad: Failed adding supply");
        projectSupply += amount_;
        emit SupplyAdded(from_, amount_);
    }

    /*
        reduceSupply()
        1. send tokens from this contract to to_
        2. update projectSupply variable
    */
    function reduceSupply(address to_, uint256 amount_) external onlyOwner{
        require(projectToken.transfer(to_, amount_), "Failed transfering the tokens");
        projectSupply -= amount_;
        emit SupplyReduced(to_, amount_);
    }
    
    /*
        buyTokens() public
        * 1. FRONTEND: Approve() tokens from the msg.sender & decimals
        * 2. require isActive & there is enough supply.
        * 3. calculate the total amount of mainCurrency to transferFrom msg.sender
        * 4. update state variables
        * 4. transferFrom() mainCurrency from msg.sender to this contract
        * 5. transfer() projectTokens to the user
    */
    function buyTokens(uint256 amountToBuy) external nonReentrant returns (bool) {
        require(isActive, "Launchapad: Round is over");
        require(projectSupply >= amountToBuy, "Launchpad: Not enough supply");
        uint amountMainCurrency = amountToBuy * projectPrice;
        projectSupply -= amountToBuy;
        collectedAmount += amountMainCurrency;
        require(mainCurrency.transferFrom(msg.sender, address(this), amountMainCurrency), "Launchpad: Failed transfering MainCurrency");
        require(projectToken.transfer(msg.sender, amountToBuy), "Launchpad: Failed transfering projectToken to the user");
        return true;
    }

    function changePrice(uint newPrice_) external onlyOwner{
        projectPrice = newPrice_;
    }



}