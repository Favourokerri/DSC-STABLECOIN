// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/helperConfig.s.sol";

contract Handler is Test {
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    ERC20Mock weth;
    ERC20Mock wbtc;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dsc = _dsc;
        dscEngine = _dscEngine;
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock mockCollateral = _getAddressFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, type(uint96).max);

        vm.startPrank(msg.sender);
        mockCollateral.mint(msg.sender, amountCollateral);
        mockCollateral.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(address(mockCollateral), amountCollateral);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock mockCollateral = _getAddressFromSeed(collateralSeed);
        uint256 maxCollateral = dscEngine.getCollateralBalanceOfUser(msg.sender, address(mockCollateral));

        amountCollateral = bound(amountCollateral, 0, maxCollateral);
        vm.assume(maxCollateral > amountCollateral);
        if (amountCollateral == 0) {
            return;
        }
        dscEngine.redeemCollateral(address(mockCollateral), amountCollateral);
    }

    function mintDSC(uint256 amountDSC) public {
        amountDSC = bound(amountDSC, 1, type(uint96).max);
        vm.startPrank(msg.sender);
        (uint256 totalDscMinted, uint256 collateralValueInUSD) = dscEngine.getAccountInfo(msg.sender);
        uint256 maxDSCToMint = (collateralValueInUSD / 2) - totalDscMinted;
        amountDSC = bound(amountDSC, 1, maxDSCToMint);
        dscEngine.mintDsc(amountDSC);
        vm.stopPrank();
    }

    //helper functions
    function _getAddressFromSeed(uint256 seed) private view returns (ERC20Mock) {
        if (seed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
