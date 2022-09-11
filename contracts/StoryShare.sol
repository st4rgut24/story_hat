// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "./SharedStructs.sol";
import "./LibraryStoryline.sol";

// import LibraryStoryline from “./LibraryStoryline.sol”;

// error codes

// DUPLICATES
// DA -- duplicate account
// DC -- duplicate cid
// DV -- duplicate vote
// DE -- duplicate entry (cant contribute more than once to a  prev contrib)

// PERMISSIONS
// PA -- only an author can do this
// PL -- only leader can do this

// STORYLINE STATUS
// SF -- must be in FINAL_REVIEW status
// SO -- must be OPEN status

// DOES NOT EXIST
// NB -- no bookmark exists
// NC -- no contribution exists
// NS -- no story exists

contract Story {
    StoryShareInterface StoryShareInst;
    bytes public cid;

    mapping(address=>bytes) public bookmarks;
    mapping(bytes => SharedStructs.Contribution) public contributions;
    mapping(address => bool) public uniqueVoters;

    mapping(address => uint8) public authorContribCounts;
    mapping(bytes => address[]) public uniqueAuthors;
    mapping(bytes => address[]) public draftVotes;
    mapping(bytes => address[]) public publishVotes;

    event storylineEvent(SharedStructs.Contribution[] storyline);

    SharedStructs.Contribution public initialContribution;

    constructor(bytes memory _storyCID, StoryShareInterface storyShareInterface) {
        cid = _storyCID;
        StoryShareInst = storyShareInterface;
        
        initialContribution = SharedStructs.Contribution(msg.sender, _storyCID, "", new bytes[](0), 0, SharedStructs.StorylineState.OPEN, address(0x0000000000000000));
    }

    function bookmark(bytes calldata _cid) external {
        bookmarks[msg.sender] = _cid;
    }

    function getDraftVotes(bytes calldata _cid) public view returns (address[] memory draftVoters) {
        draftVoters = draftVotes[_cid];
    }   

    // the leader can submit a draft for a story that is in the drafting stage
    function publishDraft(bytes memory _prevCID, bytes calldata _finalDraftCID) external {
        SharedStructs.Contribution memory finalContrib = contributions[_prevCID];
        require(finalContrib.leader == msg.sender, "PL");
        finalContrib.state = SharedStructs.StorylineState.DRAFTING_END;
        SharedStructs.Contribution memory storyContrib = contribute(_finalDraftCID, _prevCID);
        storyContrib.state = SharedStructs.StorylineState.FINAL_REVIEW;
    }

    // // request to publish a story, which terminates the story with majority vote
    // // If voters do not approve of the final story, then the leader can submit another cid for final review
    function voteToPublish(bytes calldata _cid) external returns (bool isPublished) {
        SharedStructs.Contribution storage contribution = contributions[_cid];
        SharedStructs.Contribution[] memory storyline = getStoryline(_cid);
        isPublished = LibraryStoryline.voteToPublish(uniqueAuthors, publishVotes, contribution, storyline, _cid);
    }

    // // request to close a story to submissions, and sends story to drafting phase with majority vote
    function voteToDraft(bytes calldata _cid) external returns (bool isDrafted) {
        SharedStructs.Contribution storage contribution = contributions[_cid];
        SharedStructs.Contribution[] memory storyline = getStoryline(_cid);
       isDrafted = LibraryStoryline.voteToDraft(authorContribCounts, uniqueAuthors, uniqueVoters, draftVotes, storyline, contribution, _cid);
    }

    function getStoryline(bytes calldata _cid) public returns (SharedStructs.Contribution[] memory storyline){
        SharedStructs.Contribution memory contribution = getContribution(_cid);
        uint8 contribLength = contribution.contribCount;
        storyline = new SharedStructs.Contribution[](contribLength);
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
        require(bookmarks[msg.sender].length != 0, "NB");
        bookmarkedCID = bookmarks[msg.sender];
    }

    function getContribution(bytes memory _cid) public view returns (SharedStructs.Contribution memory contribution) {
        require(contributions[_cid].authorAddr != address(0x0000000000000000), "NC");
        contribution = contributions[_cid];
    }

    // contribute to a story 
    function contribute(bytes calldata cid, bytes memory prevCID) public returns (SharedStructs.Contribution memory contribution) {
        require(contributions[cid].authorAddr == address(0x0000000000000000), "DC");
        SharedStructs.Contribution storage prevContrib = contributions[prevCID];
        if (prevCID.length != 0){
            require(prevContrib.authorAddr != address(0x0000000000000000), "NC");
            require(prevContrib.state == SharedStructs.StorylineState.OPEN, "NO");
            bytes32 ownCidHash = keccak256(cid);
            for (uint256 i=0;i<prevContrib.nextCIDs.length;i++){
                bytes memory nextCID = prevContrib.nextCIDs[i];
                if (keccak256((nextCID)) == ownCidHash){
                    revert("DE");
                }
            }
            prevContrib.nextCIDs.push(cid);
            // StoryShareInst.updateAuthorRep(prevContrib.authorAddr, 1);
            contribution = SharedStructs.Contribution(msg.sender, cid, prevCID, new bytes[](0), prevContrib.contribCount + 1, prevContrib.state, prevContrib.leader);
        }
        else { // the root contribution
            contribution = SharedStructs.Contribution(msg.sender, cid, "", new bytes[](0), 0, SharedStructs.StorylineState.OPEN, address(0x0000000000000000));
        }
        contributions[cid] = contribution;
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
        require(msg.sender == address(0x0000000000000000), "DA");        
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
        require(stories[_storyCID] == address(0x0000000000000000), 'DC');
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
        require(stories[_storyCID] != address(0x0000000000000000), 'NS');
        story = Story(stories[_storyCID]);
    }
}