// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Baazi.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./mock/Token.sol";
contract BaaziTest is Test {
    Baazi public baazi;
    Token public token;

    address public user = makeAddr("user");

    address public souyma = makeAddr("souyma");
    address public prodipto = makeAddr("prodipto");

    function setUp() public {
        vm.startPrank(user);
        token = new Token("Test Token");
        baazi = new Baazi();
        token.transfer(souyma, token.balanceOf(user) / 3);
        token.transfer(prodipto, token.balanceOf(user) / 3);
        vm.stopPrank();
    }

    function test_create_poll(uint256 amount) public {
        amount = bound(amount, 1, token.balanceOf(user));
        vm.startPrank(user);
        token.approve(address(baazi), amount);
        baazi.createPoll("Will the price of ETH go up?", 1 days, amount, token);
        vm.stopPrank();
        (
            address creator,
            string memory question,
            uint256 totalStake,
            uint256 yesStake,
            uint256 noStake,
            uint256 endTime,
            bool resolved,
            bool outcome
        ) = baazi.getPoll(0);
        assertEq(creator, user);
        assertEq(question, "Will the price of ETH go up?");
        assertEq(endTime, block.timestamp + 1 days);
        assertEq(totalStake, amount);
        assertEq(yesStake, 0);
        assertEq(noStake, 0);
        assertEq(resolved, false);
        assertEq(outcome, false);
    }

    function test_vote_yes(uint256 initialAmount, uint256 voteAmount) public {
        initialAmount = bound(initialAmount, 1, token.balanceOf(user));
        voteAmount = bound(voteAmount, 1, token.balanceOf(souyma));
        create_a_poll(initialAmount);
        vm.startPrank(souyma);
        token.approve(address(baazi), voteAmount);
        baazi.vote(0, true, voteAmount);
        vm.stopPrank();
        (, , , uint256 yesStake, uint256 noStake, , , ) = baazi.getPoll(0);
        assertEq(yesStake, voteAmount);
        assertEq(noStake, 0);
    }

    function test_vote_no(uint256 initialAmount, uint256 voteAmount) public {
        initialAmount = bound(initialAmount, 1, token.balanceOf(user));
        voteAmount = bound(voteAmount, 1, token.balanceOf(prodipto));
        create_a_poll(initialAmount);
        vm.startPrank(prodipto);
        token.approve(address(baazi), voteAmount);
        baazi.vote(0, false, voteAmount);
        vm.stopPrank();
        (, , , uint256 yesStake, uint256 noStake, , , ) = baazi.getPoll(0);
        assertEq(yesStake, 0);
        assertEq(noStake, voteAmount);
    }

    function test_resolve_poll(
        uint256 initialAmount,
        uint256 voteAmount0,
        uint256 voteAmount1,
        bool expectedOutcome
    ) public {
        initialAmount = bound(initialAmount, 1, token.balanceOf(user));
        voteAmount0 = bound(voteAmount0, 1, token.balanceOf(souyma));
        voteAmount1 = bound(voteAmount1, 1, token.balanceOf(prodipto));
        create_a_poll(initialAmount);
        vote(souyma, true, 0, voteAmount0);
        vote(prodipto, false, 0, voteAmount1);
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(user);
        baazi.resolvePoll(0, expectedOutcome);
        vm.stopPrank();
        (, , , , , , bool resolved, bool outcome) = baazi.getPoll(0);
        assertEq(resolved, true);
        assertEq(outcome, expectedOutcome);

        if (expectedOutcome) {
            uint256 expectedReward = initialAmount + voteAmount0 + voteAmount1;
            assertEq(baazi.calculateReward(0, souyma), expectedReward);
            assertEq(baazi.calculateReward(0, prodipto), 0);
        } else {
            uint256 expectedReward = initialAmount + voteAmount0 + voteAmount1;
            assertEq(baazi.calculateReward(0, souyma), 0);
            assertEq(baazi.calculateReward(0, prodipto), expectedReward);
        }
    }
    // function test_resolve_poll_claim_reward(
    //     uint256 initialAmount,
    //     uint256 voteAmount0,
    //     uint256 voteAmount1,
    //     bool expectedOutcome
    // ) public {
    //     create_a_poll(initialAmount);
    //     vote(souyma, true, 0, voteAmount0);
    //     vote(prodipto, false, 0, voteAmount1);
    //     vm.warp(block.timestamp + 1 days);
    //     baazi.resolvePoll(0, expectedOutcome);
    //     (, , , , , , bool resolved, bool outcome) = baazi.getPoll(0);
    //     if (expectedOutcome) {
    //         vm.startPrank(souyma);
    //         uint256 oldBalance = token.balanceOf(souyma);
    //         baazi.claimReward(0);
    //         uint256 newBalance = token.balanceOf(souyma);
    //         uint256 expectedReward = initialAmount + voteAmount0 + voteAmount1;
    //         assertEq(newBalance, oldBalance + expectedReward);
    //         vm.stopPrank();
    //     } else {
    //         assertEq(token.balanceOf(souyma), initialAmount / 3);
    //     }
    // }

    function create_a_poll(uint256 amount) public {
        vm.startPrank(user);
        token.approve(address(baazi), amount);
        baazi.createPoll("Will the price of ETH go up?", 1 days, amount, token);
        vm.stopPrank();
    }

    function vote(
        address voter,
        bool opinion,
        uint256 pollId,
        uint256 amount
    ) public {
        vm.startPrank(voter);
        token.approve(address(baazi), amount);
        baazi.vote(pollId, opinion, amount);
        vm.stopPrank();
    }
}
