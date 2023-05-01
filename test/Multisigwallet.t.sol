// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Multisigwallet.sol";

contract MultisigWalletTest is Test {
    MultisigWallet public multisig;

    error InvalidOwnerAddress();
    error OwnerAlreadyRegistered();
    error InvalidMinNumConfirmations();
    error NotOwner();
    error TransactionIndexDoesntExist();
    error TransactionAlreadyExecuted();
    error OwnerAlreadyVoted();
    error NotEnoughVotesToBeExecuted();

    event SubmitTransaction(
        address indexed ownerCreator,
        uint indexed index,
        address indexed to,
        uint value,
        bytes data
    );
    event AfirmativeVoteTransaction(
        address indexed owner,
        uint indexed index
    );
    event NegativeVoteTransaction(
        address indexed owner,
        uint indexed index
    );
    event ExecuteTransaction(
        address indexed owner,
        uint indexed index
    );

    address owner1 = address(0x01);
    address owner2 = address(0x02);
    address owner3 = address(0x03);
    address owner4 = address(0x04);
    address notOwner1 = address(0x05);

    function setUp() public {
        multisig = new MultisigWallet([owner1, owner2, owner3, owner4], 2);
    }

    function testConstructorDuplicateAddress() public {
        vm.expectRevert(OwnerAlreadyRegistered.selector);
        multisig = new MultisigWallet([owner1, owner2, owner4, owner4], 2);
    }

    function testConstructorWithAddress0() public {
        vm.expectRevert(InvalidOwnerAddress.selector);
        multisig = new MultisigWallet([address(0x00), owner2, owner3, owner4], 2);
    }

    function testConstructorMinNumConfirmations0() public {
        vm.expectRevert(InvalidMinNumConfirmations.selector);
        multisig = new MultisigWallet([owner1, owner2, owner3, owner4], 0);
    }

    function testConstructorMinNumConfirmationsGreaterThan4() public {
        vm.expectRevert(InvalidMinNumConfirmations.selector);
        multisig = new MultisigWallet([owner1, owner2, owner3, owner4], 5);
    }

    /* function testConstructorCheckVariables() public {
        bool owner = multisig.s_isOwner[address(0x01)];
        assertTrue(owner);
    } */

    function testSubmitTransaction() public{
        vm.expectEmit(true, true, true, true);
        vm.startPrank(owner1);
        multisig.submitTransaction(address(0), 1 ether, "0x1234");
        emit SubmitTransaction(owner1, 0, address(0), 1 ether, "0x1234");
    }

    /* function testSubmitTransactionIndexIncrement() public{
        uint256 startingIndex = multisig.s_index();
        vm.startPrank(address(0x01));
        multisig.submitTransaction(address(0), 1 ether, "0x1234");
        uint256 endingIndex = multisig.s_index();
        assertEq(endingIndex, startingIndex + 1);
    } */

    function testSubmitTransactionNotOwner() public{
        vm.expectRevert(NotOwner.selector);
        vm.startPrank(notOwner1);
        multisig.submitTransaction(address(0), 1 ether, "0x1234");
    }

    function testVoteForTransactionDoesntExistTransaction() public {
        vm.expectRevert(TransactionIndexDoesntExist.selector);
        vm.startPrank(owner1);
        multisig.voteForTransaction(0, true);
    }

    function testVoteNotOwner() public {
        vm.expectRevert(NotOwner.selector);
        vm.startPrank(notOwner1);
        multisig.voteForTransaction(0, true);
    }

    function testVoteTwice() public {
        vm.startPrank(owner1);
        multisig.submitTransaction(address(0x1), 1 ether, "0x1234");
        multisig.voteForTransaction(0, true);
        vm.expectRevert(OwnerAlreadyVoted.selector);
        multisig.voteForTransaction(0, true);
    }

    function testVoteAfirmative() public {
        vm.startPrank(owner1);
        multisig.submitTransaction(address(0x1), 1 ether, "0x1234");
        multisig.voteForTransaction(0, true);
        assertEq(multisig.getVotes(0), 1);
    }

    function testVoteNegative() public {
        vm.startPrank(owner1);
        multisig.submitTransaction(address(0x1), 1 ether, "0x1234");
        multisig.voteForTransaction(0, false);
        assertEq(multisig.getVotes(0), -1);
    }

    function testExecuteFromNotOwner() public {
        vm.startPrank(owner1);
        multisig.submitTransaction(notOwner1, 1 ether, "0x1234");
        vm.stopPrank();
        vm.startPrank(notOwner1);
        vm.expectRevert(NotOwner.selector);
        multisig.executeTransaction(0);
    }

    function testExecuteNotExistingTransaction() public {
        vm.startPrank(owner1);
        vm.expectRevert(TransactionIndexDoesntExist.selector);
        multisig.executeTransaction(0);
    }

    function testNotEnoughVotesToBeExecuted() public {
        vm.startPrank(owner1);
        multisig.submitTransaction(notOwner1, 1 ether, "0x1234");
        vm.expectRevert(NotEnoughVotesToBeExecuted.selector);
        multisig.executeTransaction(0);
    }

    function testExecuteAlreadyExecutedTransaction() public {
        vm.startPrank(owner1);
        multisig.submitTransaction(notOwner1, 1 ether, "0x1234");
        multisig.voteForTransaction(0, true);
        vm.stopPrank();
        vm.startPrank(owner2);
        multisig.voteForTransaction(0, true);
        vm.stopPrank();
        vm.startPrank(owner1);
        multisig.executeTransaction(0);
        vm.expectRevert(TransactionAlreadyExecuted.selector);
        multisig.executeTransaction(0);
    }
}
