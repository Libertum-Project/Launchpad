// SPDX-License-Identifier: UNLICENSED

// Pragma statements
// ------------------------------------
pragma solidity ^0.8.10;
pragma abicoder v2;

// Import statements
// ------------------------------------
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IPancakeRouter02.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//Contract
// ------------------------------------
contract Launchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    struct ListedProject {
        address owner; //owner of the project listed
        uint256 price; // in _pricingToken multiplied by 10 ** _decimals 
        uint256 initialVolumeOfTheToken; //how many tokens are sent by the owner
        uint256 volume; 
        uint256 collectedAmount; //set to 0
        bool isActive;
    }

    // State Variables
    // ------------------------------------

    IPancakeRouter02 pancakeSwap; //0xD99D1c33F9fC3444f8101754aBC46c52416550D1

    mapping(uint256 => bool) public nonces;
    mapping(IERC20 => ListedProject) public listedTokens;

    uint256 public collectedFees;

    uint256 internal _feePercent;
    uint256 private _decimals = 18;
    IERC20 private _pricingToken; // ERC20 Contract Address

    // Events
    // ------------------------------------
    event TokenPlaced(IERC20 token, uint256 nonce);
    event RoundFinished(IERC20 token);
    event TokensBought(IERC20 token, address buyer, uint256 amount);
    event FundsCollected(IERC20 token);

    // Functions
    // ------------------------------------
    constructor(IERC20 pricingToken_, uint256 feePercent_, IPancakeRouter02 pancakeSwap_) {
        _feePercent = feePercent_;
        _pricingToken = pricingToken_;
        pancakeSwap = pancakeSwap_;
    }

    //admin
    function setPricingToken(IERC20 pricingToken_) public { 
        _pricingToken = pricingToken_;
    }

    function listAProject(
        uint256 nonce,
        uint256 price,
        IERC20 token,
        uint256 _initialVolumeOfTheToken
    ) public {
        address sender = msg.sender;
        //require(!nonces[nonce], "Launchpad: Invalid nonce");
        require(!listedTokens[token].isActive, "Launchpad: This token was already placed");
        require(_initialVolumeOfTheToken > 0, "Launchpad: Initial Volume must be greather than 0 tokens");

        token.safeTransferFrom(sender, address(this), _initialVolumeOfTheToken);

        listedTokens[token] = ListedProject({
            owner: sender,
            price: price,
            initialVolumeOfTheToken: _initialVolumeOfTheToken,
            volume: _initialVolumeOfTheToken,
            collectedAmount: 0,
            isActive: true
        });

        nonces[nonce] = true;

        emit TokenPlaced(token, nonce);
    }

    function _sendCollectedFunds(address sender, IERC20 token) private {
        ListedProject storage listedToken = listedTokens[token];
        require(sender == listedToken.owner, "Launchpad: You are not the owner of this token");

        _pricingToken.safeTransfer(listedToken.owner, listedToken.collectedAmount);
        listedToken.collectedAmount = 0;

        emit FundsCollected(token);
    }

    function getCollectedFunds(IERC20 token) public nonReentrant {
        _sendCollectedFunds(msg.sender, token);
    }

    function finishRound(IERC20 token) public nonReentrant {
        address sender = msg.sender;
        ListedProject storage listedToken = listedTokens[token];

        require(sender == listedToken.owner, "Launchpad: You are not the owner of this token");

        _sendCollectedFunds(sender, token);

        token.safeTransfer(sender, listedToken.volume);
        delete listedTokens[token];

        emit RoundFinished(token);
    }

    function buyTokens(IERC20 token, IERC20 paymentContract, uint256 volume) public nonReentrant {
        address sender = msg.sender;
        ListedProject storage listedToken = listedTokens[token];

        require(listedToken.isActive == true, "Launchpad: Round isn't active");

        paymentContract.safeTransferFrom(sender, address(this), volume);

        if (paymentContract != _pricingToken) {
            address[] memory path = new address[](2);
            path[0] = address(paymentContract);
            path[1] = address(_pricingToken);
            paymentContract.approve(address(pancakeSwap), volume);
            volume = pancakeSwap.swapExactTokensForTokens(
                volume,
                0,
                path,
                address(this),
                block.timestamp + 100
            )[1];
        }

        uint256 tokensAmount = (volume * (10 ** _decimals)) / listedToken.price;
        require(tokensAmount <= listedToken.volume, "Launchpad: Not enough volume");

        token.safeTransfer(sender, tokensAmount);

        uint256 fee = (volume * _feePercent) / 100;
        listedToken.collectedAmount += volume - fee;
        listedToken.volume -= tokensAmount;
        collectedFees += fee;

        emit TokensBought(token, sender, tokensAmount);
    }

    //admin
    function withdrawFees() public {
        _pricingToken.safeTransfer(msg.sender, collectedFees);
        collectedFees = 0;
    }

    // View/Pure Functions
    // ------------------------------------

    function feePercent() public view returns (uint256) {
        return _feePercent;
    }

    function decimals() public view returns (uint256) {
        return _decimals;
    }

    //admin
    function setFeePercent(uint256 feePercent_) public {
        _feePercent = feePercent_;
    }

    function pricingToken() public view returns (IERC20) {
        return _pricingToken;
    }

    function getAmountByTokens(
        IERC20 token,
        IERC20 currency,
        uint256 tokensAmount
    ) public view returns (uint256 amount) {
        ListedProject storage listedToken = listedTokens[token];
        amount = (tokensAmount * listedToken.price) / (10 ** _decimals);
        if (currency != _pricingToken) {
            address[] memory path = new address[](2);
            path[0] = address(currency);
            path[1] = address(_pricingToken);
            amount = pancakeSwap.getAmountsIn(tokensAmount * listedToken.price, path)[0];
        }
    }

    function getTokensByAmount(
        IERC20 token,
        IERC20 currency,
        uint256 amount
    ) public view returns (uint256 tokensAmount) {
        ListedProject storage listedToken = listedTokens[token];
        if (currency == _pricingToken) {
            tokensAmount = (amount * (10 ** _decimals)) / listedToken.price;
        } else {
            address[] memory path = new address[](2);
            path[0] = address(currency);
            path[1] = address(_pricingToken);
            tokensAmount =
                (pancakeSwap.getAmountsOut(amount, path)[1] * (10 ** _decimals)) /
                listedToken.price;
        }
    }
}