// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

library SharedStructs {
    struct Author {
        address addr;
        bytes32 username;
        bytes profilePicCID;
        uint8 reputation;
    }
}

contract Story {
    StoryShareInterface StoryShareInst;
    bytes public cid;

    mapping(address=>bytes) public bookmarks;
    mapping(bytes => Contribution) public contributions;
    mapping(address => bool) public uniqueVoters;

    mapping(address => uint8) public authorContribCounts;
    mapping(bytes => address[]) public uniqueAuthors;
    mapping(bytes => address[]) public draftVotes;
    mapping(bytes => address[]) public publishVotes;

    event storylineEvent(Contribution[] storyline);
    event storylineLeaderEvent(address leader, bytes cid);

    enum StorylineState {
        OPEN,
        DRAFTING,
        DRAFTING_END,
        FINAL_REVIEW,
        PUBLISHED
    }

    struct Contribution {
        address authorAddr;
        bytes cid;
        bytes prevCID;
        bytes[] nextCIDs;
        uint8 contribCount;
        StorylineState state;
        address leader; // TODO: allow the author to transfer leader status to another contributor
    }

    Contribution public initialContribution;

    constructor(bytes memory _storyCID, StoryShareInterface storyShareInterface) {
        cid = _storyCID;
        StoryShareInst = storyShareInterface;
        
        initialContribution = Contribution(msg.sender, _storyCID, "", new bytes[](0), 0, StorylineState.OPEN, address(0x0000000000000000));
    }

    function getDraftVotes(bytes calldata _cid) public view returns (address[] memory draftVoters) {
        draftVoters = draftVotes[_cid];
    }   

    function bookmark(bytes calldata _cid) external {
        bookmarks[msg.sender] = _cid;
    }

    // get the unique voters from an array using a storage mapping for duplicate checks
    function setUniqueAuthors(address[] memory voters, bytes calldata _cid) internal returns (address[] memory){        
        uint8 uniqueCount = 0;
        for (uint8 j=0;j<voters.length;j++){
            if (!uniqueVoters[voters[j]]){
                uniqueCount += 1;
                uniqueVoters[voters[j]] = true;
            }
        }
        address[] memory uniqueVoterArr = new address[](uniqueCount);
        uint8 counter = 0;
        for (uint8 j=0;j<voters.length;j++){
            if (uniqueVoters[voters[j]]){
                uniqueVoterArr[counter] = voters[j];
                // clear the mapping
                delete uniqueVoters[voters[j]];
            }
        }
        uniqueAuthors[_cid] = uniqueVoterArr;
        return uniqueVoterArr;
    }

    // get authors who contributed to a storyline
    function getStorylineAuthors(Contribution[] memory contributions) internal returns (address[] memory authors) {
        authors = new address[](contributions.length);
        for (uint8 i=0;i<contributions.length;i++){
            authors[i] = contributions[i].authorAddr;
        }
    }

    // check whether the voter is valid given their past contributions
    function authorize(Contribution[] memory storyline, address[] memory authors, bytes calldata _cid, address[] memory votesArr) internal {
        bool isVoterAuthor = false;
        for (uint8 i=0;i<authors.length;i++){
            if (authors[i] == msg.sender){
                isVoterAuthor = true;
            }
            else if (i == storyline.length - 1 && !isVoterAuthor){
                revert("A non-author cannot vote to close a storyline");
            }
        }
        for (uint8 j=0;j<votesArr.length;j++){
            if (votesArr[j] == msg.sender){
                revert("can't vote to close a storyline more than once");
            }            
        }
    }

    // selects the author with the most contributions to a storyline as a leader
    function getStorylineLeader(address[] memory authors, bytes memory cid) public returns (address leader) {
        uint8 maxVotes = 0;
        address maxVoterAddr;
        for (uint8 i=0;i<authors.length;i++){
            address author = authors[i];
            uint8 contribCount = authorContribCounts[author];
            uint8 updatedContribCount = contribCount + 1;
            authorContribCounts[author] = updatedContribCount;
            if (updatedContribCount > maxVotes) {
                maxVotes = updatedContribCount;
                maxVoterAddr = author;
            }
        }
        // clear the mapping for reuse
        for (uint8 j=0;j<authors.length;j++){
            delete authorContribCounts[authors[j]];
        }        
        leader = maxVoterAddr;
        emit storylineLeaderEvent(leader, cid);
    }

    // the leader can submit a draft for a story that is in the drafting stage
    function publishDraft(bytes memory _prevCID, bytes calldata _finalDraftCID) external {
        Contribution memory finalContrib = contributions[_prevCID];
        require(finalContrib.leader == msg.sender, "only the leader can publish the final draft for a story");
        finalContrib.state = StorylineState.DRAFTING_END;
        Contribution memory storyContrib = contribute(_finalDraftCID, _prevCID);
        storyContrib.state = StorylineState.FINAL_REVIEW;
    }

    // request to publish a story, which terminates the story with majority vote
    // If voters do not approve of the final story, then the leader can submit another cid for final review
    function voteToPublish(bytes calldata _cid) external returns (bool isPublished) {
        Contribution memory contribution = contributions[_cid];
        require(contribution.state == StorylineState.FINAL_REVIEW, "can only vote to publish content that is in the final review stage");
        Contribution[] memory storyline = getStoryline(_cid);
        address[] memory authors = getStorylineAuthors(storyline);
        address[] storage publishVotesArr = publishVotes[_cid];
        authorize(storyline, authors, _cid, publishVotesArr);
        address[] memory uniqueAuthorsTotal = uniqueAuthors[_cid];
        isPublished = publishVotesArr.length > uniqueAuthorsTotal.length / 2;
        if (isPublished) {
            contribution.state = StorylineState.PUBLISHED;
        }
    }

    // request to close a story to submissions, and sends story to drafting phase with majority vote
    function voteToDraft(bytes calldata _cid) external returns (bool isDrafted) {
        Contribution[] memory storyline = getStoryline(_cid);
        address[] memory authorsArr = getStorylineAuthors(storyline);
        address[] storage draftVotesArr = draftVotes[_cid];
        authorize(storyline, authorsArr, _cid, draftVotesArr);
        
        bool isFirstToVote = draftVotesArr.length == 0;
        draftVotesArr.push(msg.sender);
        // if this is the first vote on a story, set its unique authors
        if (isFirstToVote) {
            setUniqueAuthors(authorsArr, _cid);
        }
        address[] memory uniqueAuthorsTotal = uniqueAuthors[_cid];
        isDrafted = draftVotesArr.length > uniqueAuthorsTotal.length / 2;
        Contribution memory finalContrib = storyline[storyline.length - 1];

        if (isDrafted) {
            finalContrib.state = StorylineState.DRAFTING;
        }
        finalContrib.leader = getStorylineLeader(authorsArr, finalContrib.cid);
    }

    function getStoryline(bytes calldata _cid) public returns (Contribution[] memory storyline){
        Contribution memory contribution = getContribution(_cid);
        uint8 contribLength = contribution.contribCount;
        storyline = new Contribution[](contribLength);
        uint8 idx = contribLength - 1;
        while(idx >= 0){
            storyline[idx] = contribution;
            contribution = getContribution(contribution.prevCID);
            if(contribution.contribCount == 0){
                break;
            }
        }
        emit storylineEvent(storyline);
    }

    // get the last story that the user wants to return to
    function getSavedCID() external returns (bytes memory bookmarkedCID) {
        require(bookmarks[msg.sender].length != 0, "user has not saved any bookmarks");
        bookmarkedCID = bookmarks[msg.sender];
    }

    function getContribution(bytes memory _cid) public view returns (Contribution memory contribution) {
        require(contributions[_cid].authorAddr != address(0x0000000000000000), "contribution does not exist");
        contribution = contributions[_cid];
    }

    // contribute to a story 
    function contribute(bytes calldata cid, bytes memory prevCID) public returns (Contribution memory contribution) {
        require(contributions[cid].authorAddr == address(0x0000000000000000), "cannot resubmit the same content");
        Contribution storage prevContrib = contributions[prevCID];
        require(prevContrib.authorAddr != address(0x0000000000000000), "previous contribution does not exist");
        require(prevContrib.state == StorylineState.OPEN, "the storyline has been closed");
        bytes32 ownCidHash = keccak256(cid);
        for (uint256 i=0;i<prevContrib.nextCIDs.length;i++){
            bytes memory nextCID = prevContrib.nextCIDs[i];
            if (keccak256((nextCID)) == ownCidHash){
                revert("cannot submit more than one entry to a contribution");
            }
        }
        prevContrib.nextCIDs.push(cid);
        contribution = Contribution(msg.sender, cid, prevCID, new bytes[](0), prevContrib.contribCount + 1, prevContrib.state, prevContrib.leader);
        StoryShareInst.updateAuthorRep(prevContrib.authorAddr, 1);
    }


}

interface StoryShareInterface {
    function createStory(bytes memory _storyCID) external returns(Story);
    function setFeaturedStoryCID(bytes memory _storyCID) external;
    function createAuthor(address addr, bytes32 username, bytes calldata profilePic) external;
    function getAuthor(address addr) external view returns (SharedStructs.Author memory author);
    function updateAuthorRep(address addr, uint8 reputationChange) external;
}

contract StoryShare is StoryShareInterface {
    bytes public featuredStory;
    bool public isFeaturePromoted;

    mapping(address => SharedStructs.Author) public authors;
    mapping(bytes=>address) public stories;

    constructor(){
        isFeaturePromoted = false;
    }

    function updateAuthorRep(address addr, uint8 reputationChange) external {
        SharedStructs.Author storage author = authors[addr];
        author.reputation += reputationChange;
    }

    // // for testing purposes
    // function getAuthorPublic(address addr) public view returns (SharedStructs.Author memory author) {
    //     author = authors[addr];
    // }

    function getAuthor(address addr) external view returns (SharedStructs.Author memory author) {
        author = authors[addr];
    }

    function createAuthor(address addr, bytes32 username, bytes calldata profilePic) external {
        require(msg.sender == address(0x0000000000000000), "Cannot create duplicate accounts");        
        SharedStructs.Author memory author = SharedStructs.Author(addr, username, profilePic, 0);
        authors[msg.sender] = author;
    }

    // Create a new `Story` contract and return its address.
    function createStory(
        bytes memory _storyCID
    )
        external override
        returns (Story story)
    {
        require(stories[_storyCID] == address(0x0000000000000000), 'cannot add a duplicate story cid');
        story = new Story(_storyCID, this);
        stories[_storyCID] = address(story);
        if (!isFeaturePromoted){
            featuredStory = _storyCID;
            isFeaturePromoted = false;
        }
        return story;
    }

    // Set the story that appears on the home screen of the DAPP
    function setFeaturedStoryCID(bytes memory _storyCID) external {
        isFeaturePromoted = true;
        featuredStory = _storyCID;
    }

    // // for testing purposes
    // function getStoryByCIDPublic(bytes memory _storyCID) public view returns (Story story) {
    //     require(stories[_storyCID] != address(0x0000000000000000), 'the story does not exist');
    //     story = Story(stories[_storyCID]);
    // }

    //Finds a story by its CID
    function getStoryByCID(bytes memory _storyCID) public view returns (Story story) {
        require(stories[_storyCID] != address(0x0000000000000000), 'the story does not exist');
        story = Story(stories[_storyCID]);
    }
}