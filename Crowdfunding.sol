// contracts/Crowdfunding.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFunding {
    // Stores the owner's address, set as immutable
    address private immutable owner;

    // Tracks the next available campaign ID
    uint private nextId = 1;

    // Array holding all campaign data
    Campaign[] public campaigns;

    // Boolean flag used to prevent reentrant calls
    bool private locked;

    // Modifier to ensure non-reentrancy for functions
    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    // Structure defining a crowdfunding campaign's attributes
    struct Campaign {
        uint id;
        address campaignCreator;
        string title;
        string description;
        string imageURI;
        uint goal;
        uint startsAt;
        uint endsAt;
        STATUS status;
        uint totalContributions;
        address[] contributors;
        uint[] contributionAmounts;
    }

    // Enum to represent possible statuses of a campaign
    enum STATUS {
        ACTIVE,
        DELETED,
        SUCCESSFUL,
        UNSUCCEEDED
    }

    // Events to log significant actions
    event CampaignCreated(uint indexed campaignId, address campaignCreator, string title, STATUS status);
    event CampaignDeleted(uint indexed campaignId, address campaignCreator, STATUS status);
    event ContributionMade(uint indexed campaignId, address contributor, uint amount);
    event RefundMade(uint indexed campaignId, address contributor, uint amount);

    // Constructor function to set the contract owner
    constructor() {
        owner = msg.sender;
    }

    // Modifier to restrict access to only the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    // Function to initialize a new crowdfunding campaign
    function createCampaign(
        string memory title,
        string memory description,
        string memory imageURI,
        uint goal,
        uint endsAt
    ) public {
        // Validate campaign input parameters
        require(bytes(title).length > 0, 'Title is required');
        require(bytes(description).length > 0, 'Description is required');
        require(bytes(imageURI).length > 0, 'Image URI is required');
        require(goal > 0, 'Goal must be positive');
        require(endsAt > block.timestamp, 'End time must be in the future');

        // Add a new campaign to the campaigns array
        campaigns.push(Campaign(
            nextId++,
            msg.sender,
            title,
            description,
            imageURI,
            goal,
            block.timestamp,
            endsAt,
            STATUS.ACTIVE,
            0,
            new address          new uint 
   ));

        // Emit event to log campaign creation
        emit CampaignCreated(nextId - 1, msg.sender, title, STATUS.ACTIVE);
    }

    // Function to allow users to contribute to a campaign
    function contribute(uint campaignId) public payable nonReentrant {
        // Retrieve the specified campaign
        Campaign storage campaign = campaigns[campaignId];

        // Ensure the contribution amount is valid
        require(msg.value > 0, 'Contribution must be positive');

        // Determine remaining funds required for the campaign goal
        uint remainingFundsNeeded = campaign.goal - campaign.totalContributions;

        // Handle the contribution logic
        if (msg.value <= remainingFundsNeeded) {
            campaign.totalContributions += msg.value;
        } else {
            // Calculate excess amount and refund it to contributor
            uint excessAmount = msg.value - remainingFundsNeeded;
            uint refundableAmount = msg.value - excessAmount;

            payable(msg.sender).transfer(excessAmount);

            // Update contributions with the adjusted amount
            campaign.totalContributions += refundableAmount;

            // Set campaign status to successful if goal is met
            if (campaign.totalContributions >= campaign.goal) {
                campaign.status = STATUS.SUCCESSFUL;
            }
        }

        // Record the contributor and their contribution amount
        campaign.contributors.push(msg.sender);
        campaign.contributionAmounts.push(msg.value);

        // Emit event to log the contribution
        emit ContributionMade(campaignId, msg.sender, msg.value);
    }

    // Function to allow a campaign creator to remove their campaign
    function deleteCampaign(uint campaignId) public {
        // Retrieve the specified campaign
        Campaign storage campaign = campaigns[campaignId];

        // Ensure only the creator can delete the campaign
        require(campaign.campaignCreator == msg.sender);

        // Refund all contributors upon campaign deletion
        refund(campaignId);

        // Set the campaign status to deleted
        campaign.status = STATUS.DELETED;

        // Emit event to log campaign deletion
        emit CampaignDeleted(campaignId, msg.sender, STATUS.DELETED);
    }

    // Internal function to process refunds to contributors
    function refund(uint campaignId) internal {
        // Retrieve the specified campaign
        Campaign storage campaign = campaigns[campaignId];

        // Iterate through contributors and issue refunds
        for (uint i = 0; i < campaign.contributors.length; i++) {
            address contributor = campaign.contributors[i];
            uint contributionAmount = campaign.contributionAmounts[i];

            payable(contributor).transfer(contributionAmount);

            campaign.totalContributions -= contributionAmount;
        }
    }

    // Function to retrieve all campaigns
    function getAllCampaigns() public view returns (Campaign[] memory) {
        return campaigns;
    }

    // Function to get details of a specific campaign
    function getCampaignDetails(uint campaignId) public view returns (
        uint id,
        address campaignCreator,
        string memory title,
        string memory description,
        string memory imageURI,
        uint goal,
        uint startsAt,
        uint endsAt,
        STATUS status,
        uint totalContributions,
        address[] memory contributors,
        uint[] memory contributionAmounts
    ) {
        Campaign memory campaign = campaigns[campaignId];
        return (
            campaign.id,
            campaign.campaignCreator,
            campaign.title,
            campaign.description,
            campaign.imageURI,
            campaign.goal,
            campaign.startsAt,
            campaign.endsAt,
            campaign.status,
            campaign.totalContributions,
            campaign.contributors,
            campaign.contributionAmounts
        );
    }

    // Function to get the total contributions for a specific campaign
    function getTotalContributions(uint campaignId) public view returns (uint) {
        return campaigns[campaignId].totalContributions;
    }

    // Function to get the current block timestamp
    function currentTime() public view returns (uint) {
        return (block.timestamp * 1000) + 1000;
    }

    // Function to retrieve the latest campaigns (up to the last four)
    function getLatestCampaigns() public view returns (Campaign[] memory) {
        require(campaigns.length > 0, "No campaigns found.");

        uint startIndex = campaigns.length > 4 ? campaigns.length - 4 : 0;
        uint latestCampaignsCount = campaigns.length - startIndex;

        Campaign[] memory latestCampaigns = new Campaign[](latestCampaignsCount);

        // Populate the array with the latest campaigns
        for (uint i = 0; i < latestCampaignsCount; i++) {
            latestCampaigns[i] = campaigns[campaigns.length - 1 - i];
        }

        return latestCampaigns;
    }
}
