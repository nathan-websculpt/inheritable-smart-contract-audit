//SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {InheritanceManager} from "../src/InheritanceManager.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract InheritanceManagerTest is Test {
    InheritanceManager im;
    ERC20Mock usdc;
    ERC20Mock weth;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    function setUp() public {
        vm.prank(owner);
        im = new InheritanceManager();
        usdc = new ERC20Mock();
        weth = new ERC20Mock();
    }

    function test_setNftValueSuccess() public {
        _makeTrustee();
        vm.startPrank(user3);
        im.setNftValue(1, 5e6);
        vm.stopPrank();
        assertEq(5e6, im.getNftValue(1));
    }

    function test_setNftValueFailNotTrustee() public {
        _makeTrustee();
        vm.startPrank(user2);
        vm.expectRevert();
        im.setNftValue(1, 5e6);
        vm.stopPrank();
        assertEq(2e6, im.getNftValue(1));
    }

    function test_setAssetToPaySuccess() public {
        ERC20Mock dai = new ERC20Mock();
        _makeTrustee();
        assertEq(address(usdc), im.getAssetToPay());
        vm.startPrank(user3);
        im.setAssetToPay(address(dai));
        vm.stopPrank();
        assertEq(address(dai), im.getAssetToPay());
    }

    function _makeTrustee() internal {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.createEstateNFT("our beach-house", 2e6, address(usdc));
        vm.stopPrank();
        assertEq(2e6, im.getNftValue(1));
        vm.warp(1);
        vm.warp(1 + 90 days);
        vm.startPrank(user1);
        im.inherit();
        im.appointTrustee(user3);
        vm.stopPrank();
        assertEq(user3, im.getTrustee());
    }
}
