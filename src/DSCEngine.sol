// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";

/**
 * @title Decentralized Stable Coin Enginr
 * @author Favour Okerri
 * @dev this contact is designed to be minimal and to ensure that 1 token == 1 usd peg
 */
contract DSCEngine is ReentrancyGuard {
    using SafeERC20 for IERC20;
    //====================================== Errors =======================================//

    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__LengthsDoNotMatch();
    error DSCEngine__cannotBeZeroAddress();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__BreaksHealthFactor(uint256);
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    //====================================== State variables =======================================//
    mapping(address token => address priceFeed) s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDposited;
    mapping(address user => uint256 amountDSCMinted) public s_DSCMinted;
    address[] private s_collateralTokens;
    uint256 private constant ADDITIONAL_PRICE_FEED_PRECICION = 1e10;
    uint256 private constant PRECICION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MINIMUM_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONOUS = 10;
    DecentralizedStableCoin private immutable i_dsc;

    //====================================== Events =======================================//
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    // event CollateralRedeemed(address indexed user, address indexed token, uint256 collateralAmount);
    event CollateralRedeemed(address indexed from, address indexed to, address tokenAddress, uint256 amountCollateral);

    //====================================== modifiers Functions =======================================//
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__LengthsDoNotMatch();
        }

        if (dscAddress == address(0)) {
            revert DSCEngine__cannotBeZeroAddress();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    //====================================== external Functions =======================================//

    /**
     *
     * @param tokenCollateralAddress the address of the token user want to use for collateral
     * @param amountCollateral  amount of the collateral to deposit
     * @param amountDSCToMint amount of dsc to mint
     * @dev allows user to deposit collateral and mint dsc in one go
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDSCToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDSCToMint);
    }

    /**
     * @dev this function burns and redeems collateral
     */
    function reedemCollateralForDsc(address tokenAddress, uint256 amountCollateral, uint256 amountDSC) external {
        burnDsc(amountDSC);
        redeemCollateral(tokenAddress, amountCollateral);
        // reedemCollateral alreadychecks health factor
    }

    /**
     * @param collateral the address of the token
     * @param user the address of the user to liquidate
     * @param debtToCover the amount of dsc to cover
     * @dev a liquidation is only allowed if a user is undercollaterized and the liquidtaion improves the users
     *      or the systems health factor
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MINIMUM_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUSD(collateral, debtToCover);
        //give them 10% bonus
        uint256 bonousCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONOUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonousCollateral;
        _reedemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);
        _burnDsc(debtToCover, user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // function getHealthFactor() external view returns (uint256) {}

    //====================================== Public Functions Functions =======================================//

    /**
     *
     * @param tokenCollateralAddress this is the address of the token user want to use as a collateral
     * @param amountCollateral this is the amount of collateral the user wants to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        IERC20(tokenCollateralAddress).safeTransferFrom(msg.sender, address(this), amountCollateral);
    }

    /**
     *
     * @param amountDSCToMint amount of dsc to mint
     * @dev Dsc can only be minted if the user calling this function has deposited collateral and the
     * collateral is above the liquidation threshold
     */
    function mintDsc(uint256 amountDSCToMint) public moreThanZero(amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCToMint;
        //check if health factor is broken
        _revertIfHealthFactorIsBroken(msg.sender);
        i_dsc.mint(msg.sender, amountDSCToMint);
    }

    /**
     * Redeems a users collateral if it does not break healthFactor
     */
    function redeemCollateral(address tokenAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _reedemCollateral(tokenAddress, amountCollateral, msg.sender, msg.sender);
        // check if health factor is broken
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * Burns users Dsc
     */
    function burnDsc(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    //====================================== Internal Functions =======================================//
    /**
     *
     * @param user address of the user
     * @dev returns how close to liquidation a user is..
     * if a users health factor goes below 1 then they can be liquidated
     */
    function _healthFactor(address user) internal view returns (uint256) {
        //get total dsc minted
        // get the total collateral value deposited
        (uint256 totalDscMinted, uint256 CollateralValueInUSD) = _getAccountInfo(user);
        uint256 adjustedCollateral = (CollateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (adjustedCollateral * PRECICION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // check if they have enough collateral
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MINIMUM_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _getAccountInfo(address user) internal view returns (uint256, uint256) {
        uint256 totalDscMinted = s_DSCMinted[user];
        uint256 collateralValueInUSD = getCollateralValueInUSD(user);

        return (totalDscMinted, collateralValueInUSD);
    }

    function _reedemCollateral(address tokenAddress, uint256 amountCollateral, address from, address to) internal {
        s_collateralDposited[from][tokenAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenAddress, amountCollateral);

        IERC20(tokenAddress).safeTransfer(to, amountCollateral);
        // check if health factor is broken
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function _burnDsc(uint256 amount, address onBehalfOf, address dscFrom) internal {
        s_DSCMinted[onBehalfOf] -= amount;
        IERC20(address(i_dsc)).safeTransferFrom(dscFrom, address(this), amount);
        i_dsc.burn(amount);
    }

    //======================================getters Function =======================================//
    function getCollateralValueInUSD(address user) public view returns (uint256) {
        uint256 totalCollateralInUSD;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDposited[user][token];
            totalCollateralInUSD += getUSDValue(token, amount);
        }

        return totalCollateralInUSD;
    }

    function getUSDValue(address token, uint256 amouunt) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // if eth is 1000 usd, since the price returned is e8 we have to scale it to e18 by multipying by 1e10
        // and then divide the total by 1e18
        return (uint256(price) * ADDITIONAL_PRICE_FEED_PRECICION * amouunt) / PRECICION;
    }

    function getTokenAmountFromUSD(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return (usdAmountInWei * PRECICION) / (uint256(price) * ADDITIONAL_PRICE_FEED_PRECICION);
    }

    /**
     *
     * @param tokenAddress the address of the token
     * @param user address ofuser
     * returns the amount of collateral deposited by a user for a specific token
     */
    function getUserDepositedCollateral(address tokenAddress, address user) public view returns (uint256) {
        return (s_collateralDposited[user][tokenAddress]);
    }

    function getUserHealthFactor(address user) public view returns (uint256) {
        return _healthFactor(user);
    }

    function getCollateralTokens() public view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address token) public view returns (uint256) {
        return s_collateralDposited[user][token];
    }

    function getAccountInfo(address user) public view returns (uint256, uint256) {
        return _getAccountInfo(user);
    }
}
