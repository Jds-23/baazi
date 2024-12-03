// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract Baazi is ReentrancyGuard, Ownable, Pausable {
    IERC20 public immutable token;

    struct Poll {
        address creator;
        string question;
        uint256 totalStake;
        uint256 yesStake;
        uint256 noStake;
        uint256 endTime;
        bool resolved;
        bool outcome;
        mapping(address => uint256) yesVotes;
        mapping(address => uint256) noVotes;
        mapping(address => bool) hasClaimedReward;
    }

    mapping(uint256 => Poll) public polls;
    uint256 public nextPollId;

    // Events
    event PollCreated(
        uint256 indexed pollId,
        address indexed creator,
        string question,
        uint256 endTime
    );
    event VoteCast(
        uint256 indexed pollId,
        address indexed voter,
        bool vote,
        uint256 amount
    );
    event PollResolved(uint256 indexed pollId, bool outcome);
    event RewardClaimed(
        uint256 indexed pollId,
        address indexed voter,
        uint256 amount
    );

    constructor(address _token) Ownable(msg.sender) {
        token = IERC20(_token);
    }

    function createPoll(
        string memory _question,
        uint256 _duration,
        uint256 _initialStake
    ) external whenNotPaused nonReentrant returns (uint256) {
        require(_duration > 0, "Duration must be positive");
        require(_initialStake > 0, "Initial stake required");

        uint256 pollId = nextPollId++;
        Poll storage poll = polls[pollId];

        poll.creator = msg.sender;
        poll.question = _question;
        poll.endTime = block.timestamp + _duration;

        require(
            token.transferFrom(msg.sender, address(this), _initialStake),
            "Initial stake transfer failed"
        );

        poll.totalStake = _initialStake;

        emit PollCreated(pollId, msg.sender, _question, poll.endTime);
        return pollId;
    }

    function vote(
        uint256 _pollId,
        bool _vote,
        uint256 _amount
    ) external whenNotPaused nonReentrant {
        Poll storage poll = polls[_pollId];

        require(block.timestamp < poll.endTime, "Poll has ended");
        require(!poll.resolved, "Poll is already resolved");
        require(_amount > 0, "Amount must be positive");

        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Stake transfer failed"
        );

        if (_vote) {
            poll.yesStake += _amount;
            poll.yesVotes[msg.sender] += _amount;
        } else {
            poll.noStake += _amount;
            poll.noVotes[msg.sender] += _amount;
        }

        poll.totalStake += _amount;

        emit VoteCast(_pollId, msg.sender, _vote, _amount);
    }

    function resolvePoll(uint256 _pollId, bool _outcome) external {
        Poll storage poll = polls[_pollId];

        require(msg.sender == poll.creator, "Only creator can resolve");
        require(block.timestamp >= poll.endTime, "Poll hasn't ended yet");
        require(!poll.resolved, "Poll is already resolved");

        poll.resolved = true;
        poll.outcome = _outcome;

        emit PollResolved(_pollId, _outcome);
    }

    function claimReward(uint256 _pollId) external nonReentrant {
        Poll storage poll = polls[_pollId];

        require(poll.resolved, "Poll is not resolved yet");
        require(!poll.hasClaimedReward[msg.sender], "Reward already claimed");

        uint256 reward = calculateReward(_pollId, msg.sender);
        require(reward > 0, "No reward to claim");

        poll.hasClaimedReward[msg.sender] = true;

        require(token.transfer(msg.sender, reward), "Reward transfer failed");

        emit RewardClaimed(_pollId, msg.sender, reward);
    }

    function calculateReward(
        uint256 _pollId,
        address _voter
    ) public view returns (uint256) {
        Poll storage poll = polls[_pollId];

        if (!poll.resolved) return 0;

        uint256 voterStake;
        uint256 winningPool;
        uint256 totalPool = poll.totalStake;

        if (poll.outcome) {
            voterStake = poll.yesVotes[_voter];
            winningPool = poll.yesStake;
        } else {
            voterStake = poll.noVotes[_voter];
            winningPool = poll.noStake;
        }

        if (voterStake == 0 || winningPool == 0) return 0;

        return (voterStake * totalPool) / winningPool;
    }

    // Admin functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // View functions
    function getPoll(
        uint256 _pollId
    )
        external
        view
        returns (
            address creator,
            string memory question,
            uint256 totalStake,
            uint256 yesStake,
            uint256 noStake,
            uint256 endTime,
            bool resolved,
            bool outcome
        )
    {
        Poll storage poll = polls[_pollId];
        return (
            poll.creator,
            poll.question,
            poll.totalStake,
            poll.yesStake,
            poll.noStake,
            poll.endTime,
            poll.resolved,
            poll.outcome
        );
    }

    function getVoteStake(
        uint256 _pollId,
        address _voter
    ) external view returns (uint256 yesStake, uint256 noStake) {
        Poll storage poll = polls[_pollId];
        return (poll.yesVotes[_voter], poll.noVotes[_voter]);
    }
}
