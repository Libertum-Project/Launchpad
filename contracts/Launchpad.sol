// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

// ~~~~~~~~~~~~~~ Import statements ~~~~~~~~~~~~~~

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// ~~~~~~~~~~~~~~ Contract ~~~~~~~~~~~~~~

contract Launchpad is Ownable, ReentrancyGuard {

    struct ListedProject {
        address projectOwner; //Owner of the project listed
        uint256 price; //_mainCurrency price per token of this project
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
        * 3. Check the porcentaje to the owner + porcentaje to the projectOwner <= 100 %
        * 4. TransferFrom the tokens of the project from the projectOwner to address(this)
        * 5. Create the struct for the project and add it to the mappin listedProjects[IERC20]
        * 6. emit event
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
        * finishRound() onlyowner
        * Function to close the round for an specific project
        * after, call the internal function _sendCollectedFunds to transfer the corresponding amounts
    */
    function finishRound(IERC20 project_) public onlyOwner {
        _sendCollectedFunds(project_);
        delete listedProjects[project_];
        emit RoundFinished(project_, block.timestamp);
    }

    /*
        * _sendCollectedFunds() internal
        * 1. get the project from the mapping
        * 2. get the total amount collected in the _mainCurrency
        * 3. get tokenAmount for Libertum(Owner) based on the percentage
        * 4. get tokenAmount for the projectOwner based on the percentage
        * 5. get tokenAmount for the LP based on the percentage
        * 6. transfer the corresponding amounts to owner(), projectOwner and LP
        * 7. emit 3 events corresponding to the 3 transfers 
    */
    function _sendCollectedFunds(IERC20 project_) internal {
        ListedProject memory listedProject = listedProjects[project_];
        uint256 totalCollected = listedProject.collectedAmount;
        uint256 amountForLibertum = (totalCollected * listedProject.percentageForLibertum) / 100;
        uint256 amountForTheProjectOwner =  (totalCollected * listedProject.percentageForTheProjectOwner) / 100;
        //uint256 amountForTheLP = totalCollected - amountForLibertum + amountForTheProjectOwner;
        address projectOwner_ = listedProject.projectOwner;
        require(_mainCurrency.transfer(owner(), amountForLibertum), "Launchpad: Failed sending tokens to Admin");
        require(_mainCurrency.transfer(projectOwner_, amountForTheProjectOwner), "Launchpad: Failed sending tokens to the Project owner");
        // ??????? SEND TOKENS TO THE LP ???????

        emit FundsCollectedLibertum(project_, owner(), amountForLibertum);
        emit FundsCollectedProjectOwner(project_, projectOwner_, amountForTheProjectOwner);
        //??????? emit FundsCollectedLP(project_, LP, amountForTheLP); event for the LP ???????
    }

    

    /*
        * buyTokens() public
        * 1. get project from the mapping
        * 2. require project is active
        * 3. require the project still have enough token supply
        * 4. get the LibertumAmount of tokens in proportion to the amountToBuy from the user
        * 5. call internal function _swapTokens() to make the swap of the projectToken and _mainCurrency
    */
    function buyTokens(IERC20 projectToken_, uint256 amountToBuy) public nonReentrant {
        address sender = msg.sender;
        ListedProject memory listedProject = listedProjects[projectToken_];
        require(listedProject.isActive, "Launchpad: Round isn't active");
        require(listedProject.supply >= amountToBuy, "Launchpad: No supply available");
        uint256 libertumAmount = amountToBuy * listedProject.price;      
        require(_swapTokens(sender, projectToken_, amountToBuy, libertumAmount),"Launchdpad: Failed swaping tokens");
        emit TokensBought(projectToken_, sender, amountToBuy);
    }

    /*
        * _swapTokens() internal
        * 1. transferFrom the user, the _mainCurrency token to address(this)
        * 2. transfer to the user the corresponding amount in the projectToken in exchange to the _mainCurrency
        * 3. dicrease supply of the projectToken
        * 4. increase collected amount of _mainCurrency for this project
    */
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