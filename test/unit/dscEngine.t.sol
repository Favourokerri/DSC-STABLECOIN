// SPDX mit License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/helperConfig.s.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    address ethUSDPriceFeed;
    address wbtcUSDPriceFeed;
    address weth;
    address wbtc;
    uint256 wethPrice = 2000;
    address user1 = makeAddr("user1");
    uint256 collateralAmount = 10 ether;
    uint256 dscAmount = 4 ether;
    uint256 expectedHealthFactor = 1;

    function setUp() public {
        DeployDSC deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (ethUSDPriceFeed, wbtcUSDPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();

        //mint token for users
        deal(weth, user1, collateralAmount);
        ERC20Mock(weth).mint(user1, collateralAmount);
        ERC20Mock(wbtc).mint(user1, collateralAmount);
    }

    function test_getUSDValueEth() public view {
        uint256 ethAmount = 2e18;
        uint256 price = dscEngine.getUSDValue(weth, ethAmount);
        assertEq(price, ethAmount * wethPrice);
    }

    function test_getTokenAmountFromUSD() public view {
        uint256 usdAmount = 100 ether;
        // $2000 eth /$100
        uint256 expectedAmount = 0.05 ether;
        uint256 actualAmount = dscEngine.getTokenAmountFromUSD(weth, usdAmount);

        assertEq(actualAmount, expectedAmount);
    }

    function test_deposit_collateral_cannot_be_zero() public {
        uint256 deposit_amount = 0;
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.depositCollateral(weth, deposit_amount);
    }

    function test_deposit_must_be_allowed_token() public {
        uint256 deposit_amount = 2;
        address unAllowedToken = makeAddr("unAllowedToken");
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dscEngine.depositCollateral(unAllowedToken, deposit_amount);
    }

    function test_deposit_Success_weth() public {
        vm.startPrank(user1);
        IERC20(weth).approve(address(dscEngine), collateralAmount); // users to approve
        dscEngine.depositCollateral(weth, collateralAmount);
        vm.stopPrank();

        assertEq(collateralAmount, dscEngine.getUserDepositedCollateral(weth, address(user1)));
    }

    function test_get_collateral_value() public {
        vm.startPrank(user1);
        IERC20(weth).approve(address(dscEngine), collateralAmount);
        dscEngine.depositCollateral(weth, collateralAmount);
        vm.stopPrank();

        uint256 collateralValue = dscEngine.getCollateralValueInUSD(user1);
        assertEq(collateralValue, collateralAmount * wethPrice);
    }

    function test_mint_DSC() public {
        vm.startPrank(user1);
        IERC20(weth).approve(address(dscEngine), collateralAmount);
        dscEngine.depositCollateral(weth, collateralAmount);
        dscEngine.mintDsc(2);
        vm.stopPrank();

        uint256 user1DSCBalance = IERC20(address(dsc)).balanceOf(user1);

        assertEq(user1DSCBalance, dscEngine.s_DSCMinted(user1));
    }

    function test_deposit_collateral_and_mint_dsc() public {
        vm.startPrank(user1);
        IERC20(weth).approve(address(dscEngine), collateralAmount);
        dscEngine.depositCollateralAndMintDsc(weth, collateralAmount, dscAmount);
        vm.stopPrank();

        uint256 user1DSCBalance = IERC20(address(dsc)).balanceOf(user1);

        assertEq(user1DSCBalance, dscEngine.s_DSCMinted(user1));
        assertEq(collateralAmount, dscEngine.getUserDepositedCollateral(weth, address(user1)));
    }

    function test_cannot_redeem_zero_collateral() public {
        uint256 redeemAmount = 0;
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.redeemCollateral(weth, redeemAmount);
    }

    function test_cannot_redeeme_if_health_factor_is_broken() public {
        vm.startPrank(user1);
        IERC20(weth).approve(address(dscEngine), collateralAmount);
        dscEngine.depositCollateralAndMintDsc(weth, collateralAmount, dscAmount);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));
        dscEngine.redeemCollateral(weth, collateralAmount);
    }

    // function test_cannot_mint_DSC_if_user_health_factor_is_broken() public {
    //     vm.startPrank(user1);
    //     IERC20(weth).approve(address(dscEngine), collateralAmount);
    //     dscEngine.depositCollateral(weth, collateralAmount);
    //     vm.stopPrank();

    //     uint256 amountToMint = 20000 ether;
    //     vm.prank(user1);
    //     vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
    //     dscEngine.mintDsc(amountToMint); // Minting slightly more than the adjusted collateral value
    // }
}
