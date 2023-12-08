//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DeployFountain} from "../../script/DeployFountain.s.sol";
import {Fountain} from "../../src/Fountain.sol";
import {NewTokenMock} from "../mocks/NewTokenMock.t.sol";

contract FountainTest is Test {
    event TossedEthOrToken(
        address indexed _from,
        uint256 _value,
        address _tokenAddress
    );

    Fountain fountain;
    NewTokenMock newTokenMock;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant STARTING_USERTOKEN_BALANCE = 9 ether; // Actually Link
    uint256 public constant ETHTOSS_AMOUNT = 0.5 ether;
    uint256 public constant TOKENTOSS_AMOUNT = 0.5 ether; // Actually Link
    address USER = makeAddr("user");
    address USER2 = makeAddr("user2");
    address USER3 = makeAddr("user3");

    function setUp() public {
        DeployFountain deployFountain = new DeployFountain();
        fountain = deployFountain.run();

        newTokenMock = new NewTokenMock();
        newTokenMock.transfer(USER, STARTING_USERTOKEN_BALANCE);
        newTokenMock.transfer(USER2, STARTING_USERTOKEN_BALANCE);
        newTokenMock.transfer(USER3, STARTING_USERTOKEN_BALANCE);

        vm.deal(USER, STARTING_USER_BALANCE);
        vm.deal(USER2, STARTING_USER_BALANCE);
        vm.deal(USER3, STARTING_USER_BALANCE);
    }

    function testCheckSetUp() public {
        assertEq(STARTING_USERTOKEN_BALANCE, newTokenMock.balanceOf(USER)); //THIS TEST PASSES
    }

    function testOwnerisDeployer() public {
        assertEq(fountain.owner(), msg.sender);
    }

    function testTossEth() public {
        //Arrange
        //Act
        vm.prank(USER);
        fountain.tossEth{value: ETHTOSS_AMOUNT}();
        //Assert
        assertEq(fountain.getTossers(0), USER);
        assertEq(fountain.getTotalTossedByTokenAddress(0), ETHTOSS_AMOUNT);
    }

    function testRevertsAfterTossEthEqualsZero() public {
        //Arrange //Act //Assert
        vm.prank(USER);
        vm.expectRevert(Fountain.Fountain__ValueMustBeGreaterThanZero.selector);
        fountain.tossEth{value: 0}();
    }

    function testTokenAddressesInitializeToZero() public view {
        assert(fountain.getTokenAddresses(0) == address(0));
    }

    function testTossesListByTokenAddress() public {
        //Arrange
        //Act
        vm.prank(USER);
        fountain.tossEth{value: ETHTOSS_AMOUNT}();
        vm.prank(USER2);
        fountain.tossEth{value: ETHTOSS_AMOUNT}();
        vm.prank(USER3);
        fountain.tossEth{value: ETHTOSS_AMOUNT}();

        Fountain.TosserAddressAndAmount[] memory tosses = fountain
            .getTossesByTokenAddress(address(0));

        //Console
        for (uint256 i = 0; i < tosses.length; i++) {
            console.log("Tosser Address:", tosses[i].tosserAddress);
            console.log("Amount:", tosses[i].amount);
        }
    }

    function testEthTotalCorrectAfterTosses() public {
        //Arrange
        //Act
        vm.prank(USER);
        fountain.tossEth{value: ETHTOSS_AMOUNT}();
        vm.prank(USER2);
        fountain.tossEth{value: ETHTOSS_AMOUNT}();
        vm.prank(USER3);
        fountain.tossEth{value: ETHTOSS_AMOUNT}();
        //Assert
        uint256 totalEth = fountain.getTotalTossedByTokenAddress(0);
        assertEq((ETHTOSS_AMOUNT * 3), totalEth);
    }

    function testEmitAfterTossEth() public {
        //Arrange
        //Act //Assert
        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(fountain));
        emit TossedEthOrToken(USER, ETHTOSS_AMOUNT, address(0));
        fountain.tossEth{value: ETHTOSS_AMOUNT}();
    }

    function testApproveTossToken() public {
        //Arrange
        //Act
        vm.prank(USER);
        newTokenMock.approve(address(fountain), TOKENTOSS_AMOUNT);
        console.log("USER's Link Balance:", newTokenMock.balanceOf(USER));
        console.log(
            "Fountain's Link Balance:",
            newTokenMock.balanceOf(address(fountain))
        );
        console.log(
            "Fountain's Link Allowance for USER:",
            newTokenMock.allowance(USER, address(fountain))
        );
    }

    function testTossToken() public {
        //Arrange
        vm.prank(USER);
        newTokenMock.approve(address(fountain), TOKENTOSS_AMOUNT);
        //Act
        vm.prank(USER);
        fountain.tossToken(address(newTokenMock), TOKENTOSS_AMOUNT);
        //Assert
        assertEq(fountain.getTossers(0), USER);
        assertEq(fountain.getTokenAddresses(1), address(newTokenMock)); // (1) is index for NewToken (0) is ETH
        assertEq(fountain.getTotalTossedByTokenAddress(1), TOKENTOSS_AMOUNT); // (1) is index for NewToken (0) is ETH
    }

    function testEmitAfterTossToken() public {
        //Arrange
        vm.prank(USER);
        newTokenMock.approve(address(fountain), TOKENTOSS_AMOUNT);
        //Act //Assert
        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(fountain));
        emit TossedEthOrToken(USER, TOKENTOSS_AMOUNT, address(newTokenMock));
        fountain.tossToken(address(newTokenMock), TOKENTOSS_AMOUNT);
    }

    function testRevertsAfterTossTokenEqualsZero() public {
        //Arrange
        vm.prank(USER);
        newTokenMock.approve(address(fountain), TOKENTOSS_AMOUNT);
        //Act //Assert
        vm.prank(USER);
        vm.expectRevert(Fountain.Fountain__ValueMustBeGreaterThanZero.selector);
        fountain.tossToken(address(newTokenMock), 0);
    }

    function testWithdrawEth() public {
        //Arrange
        vm.prank(USER);
        fountain.tossEth{value: ETHTOSS_AMOUNT}();
        vm.prank(USER2);
        fountain.tossEth{value: ETHTOSS_AMOUNT}();
        uint256 startingOwnerBalance = fountain.owner().balance;
        uint256 startingFountainBalance = address(fountain).balance;

        //Act
        vm.prank(fountain.owner());
        fountain.withdrawEth();
        //Assert
        assertEq(address(fountain).balance, 0);

        uint256 endingOwnerBalance = fountain.owner().balance;
        assertEq(
            startingFountainBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawWithASingleTosser() public {
        //Arrange
        uint256 startingOwnerBalance = fountain.owner().balance;
        uint256 startingFountainBalance = address(fountain).balance;

        //Act
        vm.prank(fountain.owner());
        fountain.withdrawEth();

        //Assert
        uint256 endingOwnerBalance = fountain.owner().balance;
        uint256 endingFountainBalance = address(fountain).balance;
        assertEq(endingFountainBalance, 0);
        assertEq(
            startingFountainBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawWithMultiTossers() public {
        //Arrange
        uint160 numberOfTossers = 10;
        uint160 startingTosserIndex = 1;
        for (uint160 i = startingTosserIndex; i < numberOfTossers; i++) {
            hoax(address(i), ETHTOSS_AMOUNT);
            fountain.tossEth{value: ETHTOSS_AMOUNT}();
        }
        uint256 startingOwnerBalance = fountain.owner().balance;
        uint256 startingFountainBalance = address(fountain).balance;

        //Act
        vm.prank(fountain.owner());
        fountain.withdrawEth();

        //Assert
        uint256 endingOwnerBalance = fountain.owner().balance;
        uint256 endingFountainBalance = address(fountain).balance;
        assertEq(endingFountainBalance, 0);
        assertEq(
            startingFountainBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }
}
