// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "./SharedStructs.sol";

library LibraryStoryline{
    event storylineLeaderEvent(address leader, bytes cid);

    // contribute to a story 
    function contribute(mapping(bytes => SharedStructs.Contribution) storage contributions, bytes memory cid, bytes memory prevCID) public returns (SharedStructs.Contribution memory contribution) {
        require(contributions[cid].authorAddr == address(0x0000000000000000), "DC");
        if (prevCID.length != 0){
            SharedStructs.Contribution storage prevContrib = contributions[prevCID];
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
            contribution = SharedStructs.Contribution(msg.sender, cid, prevCID, new bytes[](0), prevContrib.contribCount + 1, prevContrib.state, prevContrib.leader);
        }
        else { // the root contribution
            contribution = SharedStructs.Contribution(msg.sender, cid, "", new bytes[](0), 0, SharedStructs.StorylineState.OPEN, address(0x0000000000000000));
        }
        contributions[cid] = contribution;
    }

    // the leader can submit a draft for a story that is in the drafting stage
    function publishDraft(mapping(bytes => SharedStructs.Contribution) storage contributions, bytes memory _prevCID, bytes calldata _finalDraftCID) external {
        SharedStructs.Contribution memory finalContrib = contributions[_prevCID];
        require(finalContrib.leader == msg.sender, "PL");
        finalContrib.state = SharedStructs.StorylineState.DRAFTING_END;
        SharedStructs.Contribution memory storyContrib = contribute(contributions, _finalDraftCID, _prevCID);
        storyContrib.state = SharedStructs.StorylineState.FINAL_REVIEW;
    }

    // get the unique voters from an array using a storage mapping for duplicate checks
    function setUniqueAuthors(mapping(bytes => address[]) storage uniqueAuthors, mapping(address => bool) storage uniqueVoters, address[] memory voters, bytes calldata _cid) internal returns (address[] memory){        
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
            }
        }
        uniqueAuthors[_cid] = uniqueVoterArr;
        return uniqueVoterArr;
    }

    // request to publish a story, which terminates the story with majority vote
    // If voters do not approve of the final story, then the leader can submit another cid for final review
    function voteToPublish(mapping(bytes => SharedStructs.Contribution) storage contributions, mapping(bytes => address[]) storage uniqueAuthors, mapping(bytes => address[]) storage publishVotes, bytes calldata _cid) external returns (bool isPublished) {
        SharedStructs.Contribution memory contribution = getContribution(contributions, _cid);
        SharedStructs.Contribution[] memory storyline = getStoryline(contributions, _cid);
        address[] memory authors = getStorylineAuthors(storyline);
        address[] storage publishVotesArr = publishVotes[_cid];
        authorize(storyline, authors, _cid, publishVotesArr);
        address[] memory uniqueAuthorsTotal = uniqueAuthors[_cid];
        isPublished = publishVotesArr.length > uniqueAuthorsTotal.length / 2;
        if (isPublished) {
            contribution.state = SharedStructs.StorylineState.PUBLISHED;
        }
    }

    // request to close a story to submissions, and sends story to drafting phase with majority vote
    function voteToDraft(mapping(bytes => SharedStructs.Contribution) storage contributions, mapping(address => uint8) storage authorContribCounts, mapping(bytes => address[]) storage uniqueAuthors, mapping(address => bool) storage uniqueVoters, mapping(bytes => address[]) storage draftVotes, bytes calldata _cid) external returns (bool isDrafted) {
        SharedStructs.Contribution[] memory storyline = getStoryline(contributions, _cid);
        address[] memory authorsArr = getStorylineAuthors(storyline);
        address[] storage draftVotesArr = draftVotes[_cid];
        authorize(storyline, authorsArr, _cid, draftVotesArr);
        
        bool isFirstToVote = draftVotesArr.length == 0;
        draftVotesArr.push(msg.sender);
        // if this is the first vote on a story, set its unique authors
        if (isFirstToVote) {
            setUniqueAuthors(uniqueAuthors, uniqueVoters, authorsArr, _cid);
        }
        address[] memory uniqueAuthorsTotal = uniqueAuthors[_cid];
        isDrafted = draftVotesArr.length > uniqueAuthorsTotal.length / 2;
        SharedStructs.Contribution memory finalContrib = storyline[storyline.length - 1];

        if (isDrafted) {
            finalContrib.state = SharedStructs.StorylineState.DRAFTING;
        }
        finalContrib.leader = getStorylineLeader(authorContribCounts, authorsArr, finalContrib.cid);
    }

    function getContribution(mapping(bytes => SharedStructs.Contribution) storage contributions, bytes memory _cid) public view returns (SharedStructs.Contribution memory contribution) {
        require(contributions[_cid].authorAddr != address(0x0000000000000000), "NC");
        contribution = contributions[_cid];
    }

    function getStoryline(mapping(bytes => SharedStructs.Contribution) storage contributions, bytes calldata _cid) public view returns (SharedStructs.Contribution[] memory storyline){
        SharedStructs.Contribution memory contribution = getContribution(contributions, _cid);
        uint8 contribLength = contribution.contribCount + 1; // plus one includes the root CID 
        console.log("contribut count", contribLength);
        storyline = new SharedStructs.Contribution[](contribLength);
        if (contribLength > 0) {
            for (uint8 i=contribLength;i>=0;i--) {
                storyline[i - 1] = contribution; // most recent contrib goes to end o f array
                if (i==1){
                    break; // break so we dont execute getContrib on a root node's prev cid
                }
                contribution = getContribution(contributions, contribution.prevCID);
            }
        }
    }

    // get authors who contributed to a storyline
    function getStorylineAuthors(SharedStructs.Contribution[] memory contributions) internal returns (address[] memory authors) {
        authors = new address[](contributions.length);
        for (uint8 i=0;i<contributions.length;i++){
            authors[i] = contributions[i].authorAddr;
        }
    }

    // selects the author with the most contributions to a storyline as a leader
    function getStorylineLeader(mapping(address => uint8) storage authorContribCounts, address[] memory authors, bytes memory cid) public returns (address leader) {
        uint8 maxVotes = 0;
        for (uint8 i=0;i<authors.length;i++){
            address author = authors[i];
            uint8 updatedContribCount = authorContribCounts[author] + 1;
            authorContribCounts[author] = updatedContribCount;
            if (updatedContribCount > maxVotes) {
                maxVotes = updatedContribCount;
                leader = author;
            }
        }      
        emit storylineLeaderEvent(leader, cid);
    }    

    // check whether the voter is valid given their past contributions
    function authorize(SharedStructs.Contribution[] memory storyline, address[] memory authors, bytes calldata _cid, address[] memory votesArr) internal {
        bool isVoterAuthor = false;
        for (uint8 i=0;i<authors.length;i++){
            if (authors[i] == msg.sender){
                isVoterAuthor = true;
            }
            else if (i == storyline.length - 1 && !isVoterAuthor){
                revert("PA");
            }
        }
        for (uint8 j=0;j<votesArr.length;j++){
            if (votesArr[j] == msg.sender){
                revert("DV");
            }            
        }
    }    
}