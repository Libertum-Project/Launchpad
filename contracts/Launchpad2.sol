// SPDX-License-Identifier: UNLICENSED

//Problemas: al usar paymentSplitter 


// Pragma statements
// ------------------------------------
pragma solidity ^0.8.10;

// Import statements
// ------------------------------------
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "./IPancakeFactory.sol";
import "./IPancakeRouter02.sol";
import "./IPancakePair.sol";

// ~~~~~~~~~~~~~~ Contract ~~~~~~~~~~~~~~
//
contract Launchpad is Ownable, ReentrancyGuard {
    address constant i_pancakeFactory =
        0x6725F303b657a9451d8BA641348b6761A6CC7a17;
    address constant i_pancakeRouter =
        0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
    uint256 public immutable decimals = 10**18;
    uint256 public immutable i_percentageUSDTForLiquidityPool;
    IERC20 public immutable i_USDT; //ERC20 needed to buy this projectToken
    IERC20 public immutable i_projectToken; //ERC20 of the project
    uint256 public s_projectPrice; //price in _USDT token
    uint256 public s_projectSupply; //Initial supply of the project Token
    uint256 public s_collectedAmount; //_USDT collected
    uint256 public s_minimumAmountToPurchase; //minimum quantity of tokens the users can buy
    bool public s_isActive;
    uint256 public s_ProjectTokenAmountForLP; //amount of projectTokens that will be sent to the LP
    address[] private s_partners;
    uint256[] private s_shares;
    mapping(address => uint256) public s_tokensPurchased;

    // ~~~~~~~~~~~~~~ Events ~~~~~~~~~~~~~~
    //

    event RoundFinished(uint256 time, uint256 collectedAmount);
    event TokensBought(IERC20 token, address indexed buyer, uint256 amount);
    event SupplyAddedForLaunchpad(address from, uint256 amount);
    event SupplyAddedForLP(address from, uint256 amount);
    event SupplyReduced(address to, uint256 amount);

    // ~~~~~~~~~~~~~~ Functions ~~~~~~~~~~~~~~
    //
    constructor(
        uint256 percentageForLP_,
        IERC20 USDT_,
        IERC20 projectToken_,
        uint256 projectPrice_,
        uint256 minAmountToPurchase_,
        address[] memory payees_,
        uint256[] memory shares_
    ){
        i_percentageUSDTForLiquidityPool = percentageForLP_;
        i_USDT = USDT_;
        i_projectToken = projectToken_;
        s_projectPrice = projectPrice_;
        s_minimumAmountToPurchase = minAmountToPurchase_ * decimals;
        s_isActive = true;
        s_partners = payees_;
        s_shares = shares_;
        //Set the total sum of shares to be 100 would be better to assign percentages to the payees
        //Example: 30 shares to "X", 20 shares to "Y" and 50 shares to "P" = 100 shares(100%)
    }

    /*
        finishRound() onlyowner
        * Function to close the round for this project
        * 1. close the round, updating state variables
        * 2. first create the LP
        * 3. secondly, add liquidity to the pool
        * 2. call _distributeFunds() and require to return true
        * 3. emit event
    */

    function finishRound() external onlyOwner {
        require(s_isActive, "Launchpad: Round is over.");
        s_isActive = false;
        s_collectedAmount = 0;

        (address pair) = IPancakeFactory(i_pancakeFactory).createPair(
            address(i_USDT),
            address(i_projectToken)
        );
        require(pair != address(0),"Launchpad: Failed creating liquidity pool pair");

        _addLiquidityToLP();

        require(_distributeFunds(), "Launchpad: Unable to send funds.");
        emit RoundFinished(block.timestamp, s_collectedAmount);
    }
    
    function _addLiquidityToLP() internal returns(bool){
        uint256 amountUSDTForLP = (s_collectedAmount *  i_percentageUSDTForLiquidityPool) / 100;
        uint256 amountProjectTokenForLP = s_ProjectTokenAmountForLP;
        require(amountProjectTokenForLP > 0, "Launchpad: There are not tokens for the Liquidity Pool"); 
        
        i_USDT.approve(i_pancakeRouter, amountUSDTForLP);
        i_projectToken.approve(i_pancakeRouter, amountProjectTokenForLP);

        (, , uint256 liquidity) = IPancakeRouter02(i_pancakeRouter).addLiquidity(
            address(i_USDT),
            address(i_projectToken),
            amountUSDTForLP,
            amountProjectTokenForLP,
            amountUSDTForLP,
            amountProjectTokenForLP,
            owner(),
            block.timestamp + 10 minutes);
        require(liquidity > 0, "Launchpad: Failed adding liquidity to the LP");
        //require(IPancakePair(pair_).balanceOf(owner()) > 0, "Launchpad: Balance of owner for LP should be greater than 0");
        return true;
    }

    /*
        addSupply() 
        1. FRONTEND: from_ address must approve tokens first & decimals
        2. execute transferFrom to this contract to add projectToken
        3. update projectSupply variable
        4. emit event
    */
    function addSupplyToSell(address from_, uint256 amount_) external onlyOwner {
        require(
            i_projectToken.transferFrom(from_, address(this), amount_),
            "Launchpad: Failed adding supply"
        );
        s_projectSupply += amount_;
        emit SupplyAddedForLaunchpad(from_, amount_);
    }

    function addSupplyForLiquidityPool(address from_, uint256 amount_) external onlyOwner{
        require(
            i_projectToken.transferFrom(from_, address(this), amount_),
            "Launchpad: Failed adding supply"
        );
        s_ProjectTokenAmountForLP += amount_;
        emit SupplyAddedForLP(from_, amount_);
    }

    /*
        reduceSupply()
        1. send tokens from this contract to to_
        2. update projectSupply variable
    */
    function reduceSupply(address to_, uint256 amount_) external onlyOwner {
        require(
            i_projectToken.transfer(to_, amount_),
            "Failed transfering the tokens"
        );
        s_projectSupply -= amount_;
        emit SupplyReduced(to_, amount_);
    }

    /*
        buyTokens() public
        * 1. FRONTEND: Approve() tokens from the msg.sender & decimals
        * 2. require isActive & there is enough supply.
        * 3. calculate the total amount of USDT to transferFrom msg.sender
        * 4. update state variables
        * 4. transferFrom() USDT from msg.sender to this contract
        * 5. transfer() projectTokens to the user
    */
    function buyTokens(uint256 amountToBuy_)
        external
        nonReentrant
        returns (bool)
    {
        require(s_isActive, "Launchapad: Round is over");
        require(
            s_minimumAmountToPurchase <= amountToBuy_,
            "Launchpad: Amount is less than the minimum amount you may purchase"
        );
        require(
            s_projectSupply >= amountToBuy_,
            "Launchpad: Not enough supply"
        );
        uint256 amountUSDT = amountToBuy_ * s_projectPrice;
        s_projectSupply -= amountToBuy_;
        s_collectedAmount += amountUSDT;
        s_tokensPurchased[msg.sender] += amountToBuy_;
        require(
            i_USDT.transferFrom(
                msg.sender,
                address(this),
                amountUSDT
            ),
            "Launchpad: Failed transfering USDT"
        );
        return true;
    }

    function claimTokens() external nonReentrant {
        require(!s_isActive, "Launchpad: Please wait until the round is over");
        address sender = msg.sender;
        uint256 amountPurchasedByUser = s_tokensPurchased[sender];
        s_tokensPurchased[sender] = 0;
        require(
            amountPurchasedByUser > 0,
            "Launchpad: You did not purchase tokens"
        );
        require(
            i_projectToken.transfer(sender, amountPurchasedByUser),
            "Launchpad: Failed transfering projectToken to the user"
        );
    }

    function changePrice(uint256 newPrice_) external onlyOwner {
        s_projectPrice = newPrice_;
    }

    function pauseOrStartRound() external onlyOwner {
        s_isActive = !s_isActive;
    }

    function setMinimumAmountToPurchase(uint256 amount_) external onlyOwner {
        s_minimumAmountToPurchase = amount_;
    }

    //~~~~~~~~~~~~~~ Internal functions ~~~~~~~~~~~~~~

    /*
        _distributeFunds() internal
        * 1. copy in memory the partners length
        * 2. make a for loop to send the tokens using PaymentSplitter
        * 3. return true
    */
    function _distributeFunds() internal returns (bool) {
        address[] memory partners = s_partners;
        uint256[] memory shares = s_shares;
        uint256 partnersLength = partners.length;
        
        for (uint256 i = 0; i < partnersLength;) {
            i_USDT.transfer(partners[i], shares[i]);
            unchecked {
                i++;
            }
        }
        return true;
    }

}
