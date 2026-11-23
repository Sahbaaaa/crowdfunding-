// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Crowdfunding {
//campaign structure 
    struct Campaign {
        address proposer;
        string  name;
        string  description;
        IERC20  fundingToken;
        IERC20  rewardToken;
        uint256 exchangeRate;
        uint256 deadline;
        uint256 threshold;
        uint256 totalRaised;
        uint256 rewardTokensDeposited;
        bool    finalized;
        bool    successful;
    }
    //Campaign storage by different features
    mapping(uint256 => Campaign)                        public campaigns;
    mapping(uint256 => mapping(address => uint256))     public contributions;
    mapping(uint256 => bool)                            public proposerClaimed;
    mapping(uint256 => mapping(address => bool))        public backerClaimed;
    uint256 public campaignCount;
//Events record actions on the blockchain.
    event CampaignCreated(uint256 indexed id, address indexed proposer, uint256 threshold, uint256 deadline);
    event Contributed(uint256 indexed id, address indexed backer, uint256 amount);
    event Withdrawn(uint256 indexed id, address indexed backer, uint256 amount);
    event Finalized(uint256 indexed id, bool successful);
    event Claimed(uint256 indexed id, address indexed who, uint256 amount);

    function createCampaign(
        string  memory _name,
        string  memory _description,
        address _fundingToken,
        address _rewardToken,
        uint256 _exchangeRate,
        uint256 _deadline,
        uint256 _threshold,
        uint256 _rewardTokenAmount
    ) external returns (uint256) {
        require(_deadline > block.timestamp, "Deadline must be in the future");
        require(_threshold    > 0,           "Threshold must be positive");
        require(_exchangeRate > 0,           "Exchange rate must be positive");
        require(
            _rewardTokenAmount >= _threshold * _exchangeRate,
            "Not enough reward tokens for this threshold/rate"
        );
        require(
    IERC20(_rewardToken).balanceOf(msg.sender) >= _rewardTokenAmount,
    "Insufficient reward tokens"
);

        IERC20(_rewardToken).transferFrom(msg.sender, address(this), _rewardTokenAmount);

        uint256 id = campaignCount++;
        campaigns[id] = Campaign({
            proposer:              msg.sender,
            name:                  _name,
            description:           _description,
            fundingToken:          IERC20(_fundingToken),
            rewardToken:           IERC20(_rewardToken),
            exchangeRate:          _exchangeRate,
            deadline:              _deadline,
            threshold:             _threshold,
            totalRaised:           0,
            rewardTokensDeposited: _rewardTokenAmount,
            finalized:             false,
            successful:            false
        });

        emit CampaignCreated(id, msg.sender, _threshold, _deadline);
        return id;
    }
//Allows users to fund a campaign.
    function contribute(uint256 _campaignId, uint256 _amount) external {
        require(_campaignId < campaignCount, "Campaign does not exist");
        Campaign storage c = campaigns[_campaignId];
        require(block.timestamp < c.deadline, "Campaign deadline has passed");
        require(!c.finalized,                 "Campaign already finalized");
        require(_amount > 0,                  "Amount must be positive");
        require(c.totalRaised < c.threshold,  "Threshold already reached");

        uint256 remaining = c.threshold - c.totalRaised;
        if (_amount > remaining) {
            _amount = remaining;
        }

        c.fundingToken.transferFrom(msg.sender, address(this), _amount);
        contributions[_campaignId][msg.sender] += _amount;
        c.totalRaised += _amount;

        emit Contributed(_campaignId, msg.sender, _amount);

        if (c.totalRaised >= c.threshold) {
            c.finalized  = true;
            c.successful = true;
            emit Finalized(_campaignId, true);
        }
    }

    function withdraw(uint256 _campaignId) external {
        require(_campaignId < campaignCount, "Campaign does not exist");
        Campaign storage c = campaigns[_campaignId];
        require(!c.finalized, "Campaign already finalized");
        require(c.totalRaised < c.threshold, "Threshold already reached, cannot withdraw");
        
        uint256 amount = contributions[_campaignId][msg.sender];
        require(amount > 0, "Nothing to withdraw");

        contributions[_campaignId][msg.sender] = 0;
        c.totalRaised -= amount;
        c.fundingToken.transfer(msg.sender, amount);
        emit Withdrawn(_campaignId, msg.sender, amount);
    }

    function finalize(uint256 _campaignId) external {
        require(_campaignId < campaignCount, "Campaign does not exist");
        Campaign storage c = campaigns[_campaignId];
        require(block.timestamp >= c.deadline, "Deadline has not passed yet");
        require(!c.finalized,                  "Already finalized");
        // Prevent finalizing if threshold was already reached (auto-finalized)
        require(c.totalRaised < c.threshold,   "Already successful, cannot finalize");

        c.finalized  = true;
        c.successful = (c.totalRaised >= c.threshold);
        emit Finalized(_campaignId, c.successful);
    }

   function claim(uint256 campaignId) external  {
    require(campaignId < campaignCount, "Campaign does not exist");

    Campaign storage c = campaigns[campaignId];

    require(c.finalized, "Campaign not finalized");

    if (c.successful) {

        if (msg.sender == c.proposer) {

            require(
                !proposerClaimed[campaignId],
                "Already claimed"
            );

            proposerClaimed[campaignId] = true;

            c.fundingToken.transfer(
                msg.sender,
                c.totalRaised
            );

            emit Claimed(
                campaignId,
                msg.sender,
                c.totalRaised
            );

        } else {

            uint256 contributed =
                contributions[campaignId][msg.sender];

            require(contributed > 0, "No contribution");

            require(
                !backerClaimed[campaignId][msg.sender],
                "Already claimed"
            );

            backerClaimed[campaignId][msg.sender] = true;

            uint256 reward =
                contributed * c.exchangeRate;

            c.rewardToken.transfer(
                msg.sender,
                reward
            );

            emit Claimed(
                campaignId,
                msg.sender,
                reward
            );
        }

    } else {

        if (msg.sender == c.proposer) {

            require(
                !proposerClaimed[campaignId],
                "Already claimed"
            );

            proposerClaimed[campaignId] = true;

            c.rewardToken.transfer(
                msg.sender,
                c.rewardTokensDeposited
            );

            emit Claimed(
                campaignId,
                msg.sender,
                c.rewardTokensDeposited
            );

        } else {

            uint256 contributed =
                contributions[campaignId][msg.sender];

            require(contributed > 0, "No contribution");

            require(
                !backerClaimed[campaignId][msg.sender],
                "Already claimed"
            );

            backerClaimed[campaignId][msg.sender] = true;

            c.fundingToken.transfer(
                msg.sender,
                contributed
            );

            emit Claimed(
                campaignId,
                msg.sender,
                contributed
            );
        }
    }
}
}