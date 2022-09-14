// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
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
    SharedStructs.StoryDetails public storyDetails;
    StoryShareInterface StoryShareInst;

    mapping(bytes => SharedStructs.Contribution) public contributions;
    mapping(address => bool) public uniqueVoters;

    mapping(address => uint8) public authorContribCounts;
    mapping(bytes => address[]) public uniqueAuthors;

    mapping(bytes => address[]) public draftVotes;
    mapping(bytes => address[]) public publishVotes;

    event storylineEvent(SharedStructs.Contribution[] storyline);

    SharedStructs.Contribution public initialContribution;

    constructor(bytes memory _storyCID, string memory title, string memory summary, bytes32 genre, StoryShareInterface storyShareInterface) {
        StoryShareInst = storyShareInterface;
        
        initialContribution = contribute(_storyCID, ""); 
        storyDetails = SharedStructs.StoryDetails(_storyCID, title, summary, genre);
    }

    function getStoryDetails() public view returns(SharedStructs.StoryDetails memory) {
        return storyDetails;
    }

    function getDraftVotes(bytes calldata _cid) public view returns (address[] memory draftVoters) {
        draftVoters = draftVotes[_cid];
    }   

    // the leader can submit a draft for a story that is in the drafting stage
    function publishDraft(bytes memory _prevCID, bytes calldata _finalDraftCID) external {
        LibraryStoryline.publishDraft(contributions, _prevCID, _finalDraftCID);
    }

    // // request to publish a story, which terminates the story with majority vote
    // // If voters do not approve of the final story, then the leader can submit another cid for final review
    function voteToPublish(bytes calldata _cid) external returns (bool isPublished) {
        isPublished = LibraryStoryline.voteToPublish(contributions, uniqueAuthors, publishVotes, _cid);
    }

    // // request to close a story to submissions, and sends story to drafting phase with majority vote
    function voteToDraft(bytes calldata _cid) external returns (bool isDrafted) {
       isDrafted = LibraryStoryline.voteToDraft(contributions, authorContribCounts, uniqueAuthors, uniqueVoters, draftVotes, _cid);
    }

    function getContribution(bytes memory _cid) public view returns (SharedStructs.Contribution memory contribution) {
        require(contributions[_cid].authorAddr != address(0x0000000000000000), "NC");
        contribution = contributions[_cid];
    }

    function getStoryline(bytes calldata _cid) public view returns (SharedStructs.Contribution[] memory storyline){
        storyline = LibraryStoryline.getStoryline(contributions, _cid);
    }

    // contribute to a story 
    function contribute(bytes memory cid, bytes memory prevCID) public returns (SharedStructs.Contribution memory contribution) {
        contribution = LibraryStoryline.contribute(contributions, cid, prevCID);
        // RESTORE once you figure out how to reduce contract size
        // SharedStructs.Contribution memory prevContrib = getContribution(contribution.prevCID);
        // if (prevContrib.authorAddr != address(0x0000000000000000))
        // {
        //     StoryShareInst.updateAuthorRep(prevContrib.authorAddr, 1);
        // }
    }
}

interface StoryShareInterface {
    function createStory(bytes memory _storyCID, string memory title, string memory summary, bytes32 genre) external returns(Story);
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
    mapping(address=>bytes) public bookmarks;
    bytes[] public storyRootCIDs;

    constructor(){
        isFeaturePromoted = false;
    }

    function updateAuthorRep(address addr, uint8 reputationChange) external {
        SharedStructs.Author storage author = authors[addr];
        author.reputation += reputationChange;
    }

    function bookmark(bytes calldata _cid) external {
        bookmarks[msg.sender] = _cid;
    }

    // get the last story that the user wants to return to
    function getBookmark() external returns (bytes memory bookmarkedCID) {
        require(bookmarks[msg.sender].length != 0, "NB");
        bookmarkedCID = bookmarks[msg.sender];
    }

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
        bytes memory _storyCID,
        string memory title,
        string memory summary,
        bytes32 genre
    )
        external override
        returns (Story story)
    {
        require(stories[_storyCID] == address(0x0000000000000000), 'DC');
        story = new Story(_storyCID, title, summary, genre, this);
        stories[_storyCID] = address(story);
        if (!isFeaturePromoted){
            featuredStory = _storyCID;
            isFeaturePromoted = false;
        }
        storyRootCIDs.push(_storyCID);
        return story;
    }

    // get the root cid (story summaries) to display on the main page
    function getStoryDetails() public view returns (SharedStructs.StoryDetails[] memory storyDetailsArr) {
        storyDetailsArr = new SharedStructs.StoryDetails[](storyRootCIDs.length);
        for (uint8 i=0;i<storyRootCIDs.length;i++){
            Story story = getStoryByCID(storyRootCIDs[i]);
            storyDetailsArr[i] = story.getStoryDetails();
        }
    }

    // Set the story that appears on the home screen of the DAPP
    function setFeaturedStoryCID(bytes memory _storyCID) external {
        isFeaturePromoted = true;
        featuredStory = _storyCID;
    }

    //Finds a story by its CID
    function getStoryByCID(bytes memory _storyCID) public view returns (Story story) {
        require(stories[_storyCID] != address(0x0000000000000000), "NS");
        story = Story(stories[_storyCID]);
    }
}