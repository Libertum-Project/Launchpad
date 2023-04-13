// SPDX-License-Identifier: UNLICENSED

// Pragma statements
// ------------------------------------
pragma solidity ^0.8.10;

// Import statements
// ------------------------------------
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPancakeFactory.sol";
import "./IPancakeRouter02.sol";
import "./IPancakePair.sol";

// ~~~~~~~~~~~~~~ Contract ~~~~~~~~~~~~~~
//
contract LaunchpadLibertum is Ownable, ReentrancyGuard {

    // ~~~~~~~~~~~~~~ Contants/Immutable ~~~~~~~~~~~~~~
    address constant private PANCAKE_FACTORY =
        0x6725F303b657a9451d8BA641348b6761A6CC7a17;
    address constant private PANCAKE_ROUTER =
        0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
    uint256 public immutable decimals = 10**18;
    uint256 public immutable USDT_PERCENTAGE_FOR_LP;
    IERC20 public immutable IUSDT; //ERC20 needed to buy this projectToken
    IERC20 public immutable IPROJECT_TOKEN; //ERC20 of the project

    // ~~~~~~~~~~~~~~ State variables ~~~~~~~~~~~~~~
    uint256 private s_projectPriceInUSDT; 
    uint256 private s_projectTokenSupplyToSell;
    uint256 private s_ProjectTokenSupplyForLP; //amount of projectTokens that will be sent to the LP
    uint256 private s_minimumUnitsToPurchase; //minimum quantity of tokens the users can buy
    bool private s_isActive;
    address[] private s_partners;
    uint256[] private s_shares;
    mapping(address => uint256) private s_tokensPurchased;

    // ~~~~~~~~~~~~~~ Events ~~~~~~~~~~~~~~
    //

    event RoundFinished(uint256 time, uint256 collectedAmount);
    event TokensBought(address indexed buyer, IERC20 usdt,uint256 amountUsdt, IERC20 projectToken, uint256 amountProjectToken);
    event SupplyAddedForLaunchpad(address from, uint256 amount);
    event SupplyAddedForLP(address from, uint256 amount);
    event SupplyReduced(address to, uint256 amount);
    event PairCreated(uint256 time, address pairAddress);

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
    ) {
        USDT_PERCENTAGE_FOR_LP = percentageForLP_;
        IUSDT = USDT_;
        IPROJECT_TOKEN = projectToken_;
        s_projectPriceInUSDT = projectPrice_ * decimals;
        s_minimumUnitsToPurchase = minAmountToPurchase_ ;
        s_isActive = true;
        s_partners = payees_;
        s_shares = shares_;
        uint256 totalShares = 0;
        require(shares_.length == payees_.length, "Launchpad: Shares must match payees length");
        for(uint i=0; i<shares_.length;++i){
            totalShares+= shares_[i];
        }
        require(totalShares == 100, "Launchpad: please set 100 shares");
    }

    function finishRound() external onlyOwner {
        require(s_isActive, "Launchpad: Round is over.");
        s_isActive = false;
        uint256 collectedAmount = collectedUSDT();

        require(_distributeFunds(), "Launchpad: Unable to send funds.");
// ~~~~~~~~~~~~~~~~~~~~~~~~~ PANCAKESWAP ~~~~~~~~~~~~~~~~~~~~~~~~~
  
        (address pair) = IPancakeFactory(PANCAKE_FACTORY).createPair(
            address(IUSDT),
            address(IPROJECT_TOKEN)
        );
        require(pair != address(0),"Launchpad: Failed creating liquidity pool pair");

        require(_addLiquidityToLP()); //PANCAKESWAP

       uint256 currentTime = block.timestamp;
        emit PairCreated(currentTime, pair); //PANCAKESWAP
        emit RoundFinished(currentTime, collectedAmount);
    }

// ~~~~~~~~~~~~~~~~~~~~~~~~~ PANCAKESWAP ~~~~~~~~~~~~~~~~~~~~~~~~~
     function _addLiquidityToLP() internal returns(bool){
        uint256 collectedAmount = collectedUSDT();
        uint256 amountUSDTForLP = (collectedAmount *  USDT_PERCENTAGE_FOR_LP) / 100;
        uint256 amountProjectTokenForLP = s_ProjectTokenSupplyForLP;
        require(amountProjectTokenForLP > 0, "Launchpad: There are not tokens for the Liquidity Pool"); 
        
        IUSDT.approve(PANCAKE_ROUTER, amountUSDTForLP);
        IPROJECT_TOKEN.approve(PANCAKE_ROUTER, amountProjectTokenForLP);

        (, , uint256 liquidity) = IPancakeRouter02(PANCAKE_ROUTER).addLiquidity(
            address(IUSDT),
            address(IPROJECT_TOKEN),
            amountUSDTForLP,
            amountProjectTokenForLP,
            amountUSDTForLP,
            amountProjectTokenForLP,
            owner(),
            block.timestamp + 10 minutes);
        require(liquidity > 0, "Launchpad: Failed adding liquidity to the LP");
        return true;
    }
     
 
    //~~~~~~~~~~~~~~ OnlyOwner Functions ~~~~~~~~~~~~~~

    function changePrice(uint256 newPrice_) external onlyOwner {
        s_projectPriceInUSDT = newPrice_ * decimals;
    }

    function pauseRound() external onlyOwner {
        s_isActive = false;
    }

    function openRound() external onlyOwner{
        s_isActive = true;
    }

    function setMinimumAmountToPurchase(uint256 units_) external onlyOwner {
        s_minimumUnitsToPurchase = units_;
    }

    function addSupplyToSell(address from_, uint256 amount_) external onlyOwner {
        s_projectTokenSupplyToSell += amount_ * decimals;
        require(
            IPROJECT_TOKEN.transferFrom(from_, address(this), amount_ * decimals),
            "Launchpad: Failed adding supply"
        );
        emit SupplyAddedForLaunchpad(from_, amount_ * decimals);
    }
    
    function addSupplyForLP(address from_, uint256 amount_) external onlyOwner {
        s_ProjectTokenSupplyForLP += amount_ * decimals;
        require(
            IPROJECT_TOKEN.transferFrom(from_, address(this), amount_ * decimals),
            "Launchpad: Failed adding supply"
        );
        emit SupplyAddedForLaunchpad(from_, amount_ * decimals);
    }

    function reduceSupply(address to_, uint256 amount_) external onlyOwner {
        s_projectTokenSupplyToSell -= amount_  * decimals;
        require(
            IPROJECT_TOKEN.transfer(to_, amount_ * decimals),
            "Failed transfering the tokens"
        );
        emit SupplyReduced(to_, amount_ * decimals);
    }

    //~~~~~~~~~~~~~~ User Functions ~~~~~~~~~~~~~~

    function buyTokens(uint256 tokensToBuy)
        external
        nonReentrant
        returns (bool)
    {
        require(s_isActive, "Launchapad: Round is over");
        uint256 price = s_projectPriceInUSDT;
        uint256 minUnitToBuy = s_minimumUnitsToPurchase * decimals;
        require(
            minUnitToBuy <= tokensToBuy * decimals,
            "Launchpad: Amount is less than the minimum amount you must purchase"
        );
        require(
            s_projectTokenSupplyToSell >= tokensToBuy * decimals,
            "Launchpad: Not enough supply"
        );
        address sender = msg.sender;
        uint256 amountUSDT = tokensToBuy * price;
        s_projectTokenSupplyToSell -= tokensToBuy * decimals;
        s_tokensPurchased[sender] += tokensToBuy * decimals;
        require(
            IUSDT.transferFrom(
                sender,
                address(this),
                amountUSDT
            ),
            "Launchpad: Failed transfering USDT"
        );
        emit TokensBought(sender, IUSDT, amountUSDT, IPROJECT_TOKEN, tokensToBuy * decimals);
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
            IPROJECT_TOKEN.transfer(sender, amountPurchasedByUser),
            "Launchpad: Failed transfering projectToken to the user"
        );
    }


    //~~~~~~~~~~~~~~ Internal functions ~~~~~~~~~~~~~~

    function _distributeFunds() internal returns (bool) {
        uint256 totalUSDTFunds = collectedUSDT();
        uint256 totalUSDTForLP = (totalUSDTFunds * USDT_PERCENTAGE_FOR_LP) / 100;
        uint256 totalUSDTForPartners = totalUSDTFunds - totalUSDTForLP;
        address[] memory partners = s_partners;
        uint256[] memory shares = s_shares;
        uint256 partnersLength = partners.length;
        
        for (uint256 i = 0; i < partnersLength;) {
            uint256 amountForPartnerI = (totalUSDTForPartners * shares[i]) / 100;
            require(IUSDT.transfer(partners[i], amountForPartnerI), "Launchpad: error distributing the funds");
            unchecked {
                i++;
            }
        }
        return true;
    }

    //~~~~~~~~~~~~~~ View/Pure functions ~~~~~~~~~~~~~~

    function collectedUSDT() public view returns(uint256){
        return IUSDT.balanceOf(address(this));
    }

    function projectPrice() external view returns(uint256){
        return s_projectPriceInUSDT;
    }

    function currentTokenSupplyForSell() external view returns(uint256){
        return s_projectTokenSupplyToSell;
    }

    function tokenSupplyForLP() external view returns(uint256){
        return s_ProjectTokenSupplyForLP;
    }

    function minimumAmountToPurchase() external view returns(uint256){
        return s_minimumUnitsToPurchase;
    }

    function partnersByIndex(uint256 index) external view returns(address){
        return s_partners[index];
    }

    function sharesByIndex(uint256 index) external view returns(uint256){
        return s_shares[index];
    }

    function tokensPurchasedByUser(address user) external view returns(uint256){
        return s_tokensPurchased[user];
    }

    function launchpadIsActive() external view returns(bool){
        return s_isActive;
    }

}
