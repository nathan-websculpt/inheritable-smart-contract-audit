//SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {InheritanceManager} from "../src/InheritanceManager.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// attacking
// contractInteractions(address _target, bytes calldata _payload, uint256 _value, bool _storeTarget)
// contract ReentrancyAttacker {
//     InheritanceManager im;
//     address target; // x

//     constructor(address _im, address _target) {
//         im = InheritanceManager(_im);
//         target = _target;
//     }

//     function attack() external payable {
//         im.contractInteractions(address(this), abi.encodeWithSignature("receive()"), msg.value, false);
//     }

//     fallback() external payable {
//         if (address(im).balance >= msg.value) {
//             im.contractInteractions(address(this), abi.encodeWithSignature("receive()"), msg.value, false);
//         }
//     }

//     receive() external payable {
//         if (address(im).balance >= msg.value) {
//             im.contractInteractions(address(this), abi.encodeWithSignature("receive()"), msg.value, false);
//         }
//     }
// }

contract InheritanceManagerTest is Test {
    InheritanceManager im;
    ERC20Mock usdc;
    ERC20Mock weth;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");

    function setUp() public {
        vm.prank(owner);
        im = new InheritanceManager();
        usdc = new ERC20Mock();
        weth = new ERC20Mock();
    }

    // function test_reentrancyAttack() public {
    //     vm.deal(address(im), 10e18);
    //     vm.deal(address(owner), 2e18);

    //     ReentrancyAttacker attacker = new ReentrancyAttacker(address(im), owner);

    //     uint256 startingAttackContractBalance = address(attacker).balance;
    //     uint256 startingInheritanceManagerContractBalance = address(im).balance;

    //     vm.startPrank(owner);

    //     // vm.startPrank(user1); //shouldn't be able to run as user1

    //     im.contractInteractions(address(attacker), abi.encodeWithSignature("attack()"), 1e18, false);

    //     // vm.expectRevert();
    //     // attacker.attack{value: 1e18}();

    //     // assertEq(address(im).balance, 9e18); // Assuming the contract is vulnerable and only loses the intended amount
    //     // assertEq(user1.balance, 1e18);

    //     vm.stopPrank();

    //     console.log("attacker contract balance: ", startingAttackContractBalance);
    //     console.log("InheritanceManager balance: ", startingInheritanceManagerContractBalance);
    //     console.log("ending attacker contract balance: ", address(attacker).balance);
    //     console.log("ending InheritanceManager balance: ", address(im).balance);
    //     console.log("ending Owner balance: ", address(owner).balance);
    // }

    // audit is in judging phase, this test is from the following submission, titled:
    // "Ownership Can Be Stolen After Deadline Due To Frontrun in InheritanceManager.sol::inherit() function"
    // https://codehawks.cyfrin.io/c/2025-03-inheritable-smart-contract-wallet/s/18
    function test_AttackerCanFrontRunOwnerAfterDeadlinePassed() public {
        uint256 balance = 100000e6;
        address imAddress = address(im);

        vm.startPrank(owner);
        // mint 100k USDC to owner
        usdc.mint(owner, balance);
        // owner sets backup account
        im.addBeneficiery(user1);
        // transfer USDC ofrom owner to im
        usdc.transfer(imAddress, balance);
        vm.stopPrank();

        // assert valid transfers
        assertEq(usdc.balanceOf(owner), 0);
        assertEq(usdc.balanceOf(imAddress), balance);

        address attacker = address(0x52);

        // 90 days pass, no activity
        vm.warp(block.timestamp + 90 days + 1);

        // attacker
        vm.startPrank(attacker);
        // fronrun owner's tx and steal ownership
        im.inherit();
        // remove beneficiary
        im.removeBeneficiary(user1);
        // transfer all funds to attacker's wallet
        im.sendERC20(address(usdc), balance, attacker);
        vm.stopPrank();

        assertEq(usdc.balanceOf(attacker), balance);
        assertEq(usdc.balanceOf(imAddress), 0);
    }

    // https://codehawks.cyfrin.io/c/2025-03-inheritable-smart-contract-wallet/s/35
    function test_withdrawInheritedFundsWillRevertWhenTransferingERC20() public {
        uint256 balance = 100000e6;
        address imAddress = address(im);

        address alice = address(0x01);
        address bob = address(0x02);
        address john = address(0x03);

        vm.startPrank(owner);
        // mint 100k USDC to owner
        usdc.mint(owner, balance);
        // owner sets 3 beneficiaries [Alice, Bob, John]
        im.addBeneficiery(alice);
        im.addBeneficiery(bob);
        im.addBeneficiery(john);
        // transfer USDC from owner to im
        usdc.transfer(imAddress, balance);
        // remove bob as he is the middle child...
        // [Alice, 0x00, John]
        im.removeBeneficiary(bob);
        vm.stopPrank();

        // 90 days pass, no activity
        vm.warp(block.timestamp + 90 days + 1);

        // inherit the funds of owner
        im.inherit();

        // withdraw funds and allocate among beneficiaries will revert for ERC20
        vm.expectRevert();
        im.withdrawInheritedFunds(address(usdc));
    }

    // https://codehawks.cyfrin.io/c/2025-03-inheritable-smart-contract-wallet/s/86
    function test_ownerPrivilegesAfterInheritance() public {
        address alice = address(0x09);
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(alice);
        vm.warp(1 + 90 days);
        vm.deal(address(im), 5e18);
        im.inherit(); // doesn't matter who calls this.
        im.removeBeneficiary(alice); //should not be possible after inheritance.
        im.addBeneficiery(owner); // owner access
        im.sendETH(5e18, owner);
        vm.stopPrank();
        assertEq(0, address(im).balance);
    }

    function test_sendERC20FromOwner() public {
        usdc.mint(address(im), 10e18);
        weth.mint(address(im), 10e18);
        vm.startPrank(owner);
        im.sendERC20(address(weth), 1e18, user1);
        assertEq(weth.balanceOf(address(im)), 9e18);
        assertEq(weth.balanceOf(user1), 1e18);
        vm.stopPrank();
    }

    function test_sendERC20FromUserFail() public {
        usdc.mint(address(im), 10e18);
        weth.mint(address(im), 10e18);
        vm.startPrank(user1);
        vm.expectRevert();
        im.sendERC20(address(weth), 1e18, user1);
        assertEq(weth.balanceOf(address(im)), 10e18);
        vm.stopPrank();
    }

    function test_sendERC20FromOwnerDeadlineUpdate() public {
        uint256 deadline = im.getDeadline();
        uint256 expectedDeadline = 1 + 90 days;
        usdc.mint(address(im), 10e18);
        weth.mint(address(im), 10e18);
        vm.warp(10);
        vm.startPrank(owner);
        im.sendERC20(address(weth), 1e18, user1);
        assertEq(weth.balanceOf(address(im)), 9e18);
        assertEq(weth.balanceOf(user1), 1e18);
        deadline = im.getDeadline();
        expectedDeadline = 10 + 90 days;
        assertEq(deadline, expectedDeadline);
        vm.stopPrank();
    }

    function test_sendEtherFromOwner() public {
        vm.deal(address(im), 10e18);
        vm.startPrank(owner);
        im.sendETH(1e18, user1);
        assertEq(address(im).balance, 9e18);
        assertEq(user1.balance, 1e18);
        vm.stopPrank();
    }

    function test_sendEtherFromUserFail() public {
        vm.deal(address(im), 10e18);
        vm.startPrank(user1);
        vm.expectRevert();
        im.sendETH(1e18, owner);
        assertEq(address(im).balance, 10e18);
        vm.stopPrank();
    }

    function test_sendEtherFromOwnerDeadlineUpdate() public {
        uint256 deadline = im.getDeadline();
        uint256 expectedDeadline = 1 + 90 days;
        vm.deal(address(im), 10e18);
        vm.warp(10);
        vm.startPrank(owner);
        im.sendETH(1e18, user1);
        assertEq(address(im).balance, 9e18);
        assertEq(user1.balance, 1e18);
        deadline = im.getDeadline();
        expectedDeadline = 10 + 90 days;
        assertEq(deadline, expectedDeadline);
        vm.stopPrank();
    }

    function test_addBeneficiarySuccess() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        vm.stopPrank();
        assertEq(0, im._getBeneficiaryIndex(user1));
    }

    function test_addBeneficiaryFail() public {
        vm.startPrank(user1);
        vm.expectRevert();
        im.addBeneficiery(user1);
        vm.stopPrank();
    }

    function test_removeBeneficiary() public {
        address user2 = makeAddr("user2");
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        vm.stopPrank();
        assertEq(0, im._getBeneficiaryIndex(user1));
        assertEq(1, im._getBeneficiaryIndex(user2));
        vm.startPrank(owner);
        im.removeBeneficiary(user2);
        vm.stopPrank();
        assert(1 != im._getBeneficiaryIndex(user2));
    }

    function test_inheritBeforeDeadline() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 10e10);
        vm.warp(1 + 80 days);
        vm.startPrank(user1);
        vm.expectRevert();
        im.inherit();
        vm.stopPrank();
        assertEq(owner, im.getOwner());
    }

    function test_inheritOnlyOneBeneficiary() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 10e10);
        vm.warp(1 + 90 days);
        vm.startPrank(user1);
        im.inherit();
        vm.stopPrank();
        assertEq(user1, im.getOwner());
    }

    function test_inheritMultipleBeneficiaries() public {
        address user2 = makeAddr("user2");
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 10e10);
        vm.warp(1 + 90 days);
        vm.startPrank(user1);
        im.inherit();
        vm.stopPrank();
        assertEq(owner, im.getOwner());
        assertEq(true, im.getIsInherited());
    }

    function test_withdrawInheritedFundsFail() public {
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 10e10);
        vm.warp(1 + 90 days);
        vm.startPrank(user1);
        vm.expectRevert();
        im.withdrawInheritedFunds(address(0));
        vm.stopPrank();
    }

    function test_withdrawInheritedFundsEtherSuccess() public {
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 9e18);
        vm.warp(1 + 90 days);
        vm.startPrank(user1);
        im.inherit();
        im.withdrawInheritedFunds(address(0));
        vm.stopPrank();
        assertEq(3e18, user1.balance);
        assertEq(3e18, user2.balance);
        assertEq(3e18, user3.balance);
    }

    function test_withdrawInheritedFundsERC20Success() public {
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        vm.stopPrank();
        vm.warp(1);
        usdc.mint(address(im), 9e18);
        vm.warp(1 + 90 days);
        vm.startPrank(user1);
        im.inherit();
        im.withdrawInheritedFunds(address(usdc));
        vm.stopPrank();
        assertEq(3e18, usdc.balanceOf(user1));
        assertEq(3e18, usdc.balanceOf(user2));
        assertEq(3e18, usdc.balanceOf(user3));
    }

    function test_buyOutEstateNFTFailNotInherited() public {
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        im.createEstateNFT("our beach-house", 2000000, address(usdc));
        vm.stopPrank();
        vm.startPrank(user1);
        vm.expectRevert();
        im.buyOutEstateNFT(1);
        vm.stopPrank();
    }

    function test_buyOutEstateNFTFailNotBeneficiary() public {
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        address user4 = makeAddr("user4");
        vm.warp(1);
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        im.createEstateNFT("our beach-house", 2000000, address(usdc));
        vm.stopPrank();
        vm.warp(1 + 90 days);
        vm.startPrank(user4);
        im.inherit();
        vm.expectRevert();
        im.buyOutEstateNFT(1);
        vm.stopPrank();
    }

    function test_buyOutEstateNFTSuccess() public {
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        vm.warp(1);
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        im.createEstateNFT("our beach-house", 3e6, address(usdc));
        vm.stopPrank();
        usdc.mint(user3, 4e6);
        vm.warp(1 + 90 days);
        vm.startPrank(user3);
        usdc.approve(address(im), 4e6);
        im.inherit();
        im.buyOutEstateNFT(1);
        vm.stopPrank();
    }

    function test_appointTrusteeSuccess() public {
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 9e18);
        vm.warp(1 + 90 days);
        vm.startPrank(user1);
        im.inherit();
        im.appointTrustee(user3);
        vm.stopPrank();
        assertEq(user3, im.getTrustee());
    }
}
