// SPDX-License-Identifier: UNLICENSED

// Pragma statements
// ------------------------------------
pragma solidity ^0.8.10;
pragma abicoder v2;

// Import statements
// ------------------------------------
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// ~~~~~~~~~~~~~~ Contract ~~~~~~~~~~~~~~
//
contract Launchpad is Ownable, ReentrancyGuard {

    struct ListedProject {
        address projectOwner; //Owner of the project listed
        uint256 price; //LibertumToken price 
        uint256 supply; //Initial supply of the project Token
        uint256 collectedAmount; //LibertumToken collected
        uint256 percentageForLibertum;
        uint256 percentageForTheProjectOwner;
        uint256 percentageForTheLP;
        uint256 timeListed; //listing block.timestamp
        bool isActive;
    }

    // ~~~~~~~~~~~~~~ State Variables ~~~~~~~~~~~~~~
    //
    mapping(IERC20 => ListedProject) public listedProjects; 

    uint256 public collectedFees;

    uint256 private _decimals = 18;
    IERC20 private _mainCurrency; //Libertum ERC20

    // ~~~~~~~~~~~~~~ Events ~~~~~~~~~~~~~~
    //
    event ProjectListed(IERC20 token, uint256 initialVolume, address indexed projectOwner);
    event RoundFinished(IERC20 token, uint time);
    event TokensBought(IERC20 token, address indexed buyer, uint256 amount);
    event FundsCollectedLibertum(IERC20 indexed project, address indexed Libertum, uint256 amount);
    event FundsCollectedProjectOwner(IERC20 indexed project, address indexed ProjectOwner, uint256 amount);
    event FundsCollectedLP(IERC20 indexed project, address indexed LP, uint256 amount);



    // ~~~~~~~~~~~~~~ Functions ~~~~~~~~~~~~~~
    //
    constructor(IERC20 LibertumToken_) {
        _mainCurrency = LibertumToken_;
    }

    /*
        * setCurrency() OnlyOwner
        * Change the currency of the launchpad 
        * ONLY with this _mainCurrency, the users can buy in the launchpad
    */
    function setCurrency(IERC20 token_) public onlyOwner { 
        _mainCurrency = token_;
    }


    /*
        * listAProject() OnlyOwner
        * 1. Check the project is not active yet (must return false)
        * 2. Check the initial volume of the projectToken is greather than 0
        * 3. Create the struct for the project and add it to the mappin listedProjects[IERC20]
    */
    function listAProject(
        address projectOwner_,
        uint256 price_,
        IERC20 projectToken_,
        uint256 initialVolumeOfTheToken_,
        uint256 percentageForLibertum_,
        uint256 percentageForTheProjectOwner_
    ) public onlyOwner {
        require(!listedProjects[projectToken_].isActive, "Launchpad: This project is already listed");
        require(initialVolumeOfTheToken_ > 0, "Launchpad: Initial Volume must be greather than 0 tokens");
        require((percentageForLibertum_ + percentageForTheProjectOwner_ ) <= 100, "Launchpad: Invalid percentages");
        
        // ??????? Should transferFrom from msg.sender, Admin, or projectOwner ???????
        require(projectToken_.transferFrom(projectOwner_, address(this), initialVolumeOfTheToken_), "Launchpad: Error transfering the project Token");

        listedProjects[projectToken_] = ListedProject({
            projectOwner: projectOwner_,
            price: price_,
            supply: initialVolumeOfTheToken_,
            collectedAmount: 0,
            percentageForLibertum: percentageForLibertum_,
            percentageForTheProjectOwner: percentageForTheProjectOwner_,
            percentageForTheLP: (100 - (percentageForLibertum_ + percentageForTheProjectOwner_)),
            timeListed: block.timestamp,
            isActive: true
        });

        emit ProjectListed(projectToken_, initialVolumeOfTheToken_, projectOwner_);
    }

    /*
        * _sendCollectedFunds() internal
        * 1. get the project from the mapping
        * 2. get the total amount collected
        * 3. get tokenAmount for Libertum
        * 4. get tokenAmount for the projectOwner
        * 5. get tokenAmount for the LP
        * 6. g
    */
    function _sendCollectedFunds(IERC20 project_) internal {
        ListedProject memory listedProject = listedProjects[project_];
        uint256 totalCollected = listedProject.collectedAmount;
        uint256 amountForLibertum = totalCollected * (listedProject.percentageForLibertum / 100);
        uint256 amountForTheProjectOwner =  totalCollected * (listedProject.percentageForTheProjectOwner / 100);
        //uint256 amountForTheLP = totalCollected - amountForLibertum + amountForTheProjectOwner;
        address projectOwner_ = listedProject.projectOwner;
        listedProjects[project_].collectedAmount = 0;
        require(_mainCurrency.transfer(owner(), amountForLibertum), "Launchpad: Failed sending tokens to Admin");
        require(_mainCurrency.transfer(projectOwner_, amountForTheProjectOwner), "Launchpad: Failed sending tokens to the Project owner");
        // ??????? SEND TOKENS TO THE LP ???????

        emit FundsCollectedLibertum(project_, owner(), amountForLibertum);
        emit FundsCollectedProjectOwner(project_, projectOwner_, amountForLibertum);
        //??????? emit FundsCollectedLP(project_, LP, amountForTheLP); event for the LP ???????
    }

    function getCollectedFunds(IERC20 project_) public onlyOwner {
        _sendCollectedFunds(project_);
    }

    function finishRound(IERC20 project_) public onlyOwner {
        _sendCollectedFunds(project_);
        delete listedProjects[project_];
        emit RoundFinished(project_, block.timestamp);
    }

    /*
        * buyTokens()
        * 1. get project from the mapping
        * 2. require project is active
        * 3. require the project still have enough token supply
        * 4. get the LibertumAmount of tokens in proportion to the amountToBuy
    */

    function buyTokens(IERC20 projectToken_, uint256 amountToBuy) public nonReentrant {
        address sender = msg.sender;
        ListedProject memory listedProject = listedProjects[projectToken_];
        require(listedProject.isActive, "Launchpad: Round isn't active");
        require(listedProject.supply >= amountToBuy, "Launchpad: No supply available");
        uint256 libertumAmount = amountToBuy * listedProject.price;
               
        _swapTokens(sender, projectToken_, amountToBuy, libertumAmount);
           

        emit TokensBought(projectToken_, sender, amountToBuy);
    }

    function _swapTokens(address user_, IERC20 projectToken_, uint256 amountProjectToken_,uint256 amountLibertum_) internal returns(bool){
        require(_mainCurrency.transferFrom(user_, address(this), amountLibertum_), "Launchpad: Transfer main currency failed");
        require(projectToken_.transfer(user_, amountProjectToken_),"Launchpad: Transfering project token failed");
        listedProjects[projectToken_].supply -= amountProjectToken_;
        listedProjects[projectToken_].collectedAmount += amountLibertum_;    
        return true;
    }

    // View/Pure Functions
    //
    function pricingToken() public view returns (IERC20) {
        return _mainCurrency;
    }



}