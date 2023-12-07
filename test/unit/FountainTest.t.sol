//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
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
    // LinkTokenMock linkTokenMock;
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
        fountain.approveTossToken(address(newTokenMock), TOKENTOSS_AMOUNT);
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
        fountain.approveTossToken(address(newTokenMock), TOKENTOSS_AMOUNT);
        //Act
        vm.prank(USER);
        fountain.tossToken(address(newTokenMock), TOKENTOSS_AMOUNT);
        //Assert
        // assertEq(fountain.getTossers(1), USER);
        // assertEq(fountain.getTotalTossedByTokenAddress(0), TOKENTOSS_AMOUNT);
    }
}
