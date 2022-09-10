import {Story} from "../artifacts/contracts/StoryShare.sol/StoryShare.json"

import { ethers } from "hardhat";
import { expect } from "chai";

describe('Story', async () => {
    const rootStoryCID = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKoE";

    const authorAddr = "0x5ADB78276219bAf90577453A9BdDd5f200452D9C";
    const username = "the_light_of_aiur";
    const profilePic = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKoa"; // default profile pic

    const authorAddr2 = "0xB620c98D859F098bC38Ae9c7531a34ec8d3F06CB";
    const username2 = "the_darkness_of_blades";
    const profilePic2 = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKob"; // default profile pic    

    enum StorylineState {
        OPEN,
        DRAFTING,
        FINAL_REVIEW,
        PUBLISHED
    }

    const contributionCID = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKoc";
    const contributionCID2 = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKod";
    const contributionCID3 = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKoe";
    const contributionCID4 = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKof";
    const contributionCID5 = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKog";
    const contributionCIDList = [contributionCID, contributionCID2, contributionCID3, contributionCID4, contributionCID5];

    const Story = await ethers.getContractFactory("Story");
    var story: Story;
    var author: any;
    var author2: any;

    beforeEach(async () => {
        story = await Story.deploy();
        author = await story.createAuthor(authorAddr, username, profilePic);
        author2 = await story.createAuthor(authorAddr2, username2, profilePic2);
    })

    it('assigns the first contribution', async () => {
        await story.contribute(contributionCID, rootStoryCID, {from:author.addr});
        const firstContributionCID = await story.firstContributionCID();
        expect(firstContributionCID).to.equal(contributionCID);
    })

    it('assigns subsequent contributions', async () => {
        await story.contribute(contributionCID, rootStoryCID, {from:author.addr});
        await story.contribute(contributionCID2, contributionCID, {from:author.addr});
        const contribution = await story.getContribution(contributionCID2);
        const firstContrib = await story.getContribution(contributionCID);
        // sets prev contrib pointer
        expect(contribution.prevCID).to.equal(contributionCID);
        // sets next contrib pointer
        expect(firstContrib.nextCIDs).length.to.equal(1);
        expect(firstContrib.nextCIDS[0]).to.equal(contributionCID2);
    })

    it('bookmark a contribution', async () => {
        await story.contribute(contributionCID, rootStoryCID, {from:author.addr});
        await story.bookmark(contributionCID);
        const savedCID = await story.getSavedCID();
        expect(savedCID).to.equal(contributionCID);
    })

    it('links a contribution to its author', async () => {
        await story.contribute(contributionCID, rootStoryCID, {from:author.addr});
        const contribution = await story.getContribution(contributionCID);
        expect(contribution.author).to.equal(author);
    });

    it('adds unique authors', async () => {
        const authors = await story.getAuthors();
        expect(authors.length).to.equal(0);
        await story.contribute(contributionCID, {from:author.addr});
        expect(authors.length).to.equal(1);
        await story.contribute(contributionCID2, {from:author.addr});
        expect(authors.length).to.equal(1);
    });

    describe('a storyline', async () => {
        let actualContribList: string[] = [];

        for (let i=0;i<contributionCIDList.length;i++){
            let prevCid = i === 0 ? rootStoryCID : contributionCIDList[i-1];
            let storylineAuthor = i%2 == 0 ? author : author2;
            await story.contribute(contributionCIDList[i], prevCid, {from:storylineAuthor.addr});            
        }

        const finalContrib = await story.getContribution(contributionCIDList[contributionCIDList.length - 1]);
        let finalDraftContrib: { state: any; cid: any; }; // the contribution that includes the whole storyline

        it('creates a path from leaf node to root node', async () => {     
            actualContribList = await story.getStoryline(finalContrib.cid);  
            for (let i=0;i<contributionCIDList.length;i++){
                expect(actualContribList[i]).to.equal(contributionCIDList[i]);            
            }
        })

        it('reverts when a non-author tries to close a storyline', async () => {
            const outsiderAddr = "0xB620c98D8S9F098bC38Ae9c7531a34ec8d3F06CB";
            const outsiderUsername = "anon";
            const outsiderProfilePic = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKoEh"; // default profile pic    
        
            const otherAuthor = await story.createAuthor(outsiderAddr, outsiderUsername, outsiderProfilePic);
            await expect(story.voteToDraft(finalContrib.cid, {from: otherAuthor.addr})).to.be.revertedWith("A non-author cannot vot to close a storyline");
        })

        it("closes a storyline to public submissions when a majority of authors vote", async () => {
            await story.voteToDraft(finalContrib.cid, {from: author.addr});
            let closeVotes = await story.closeVotes(finalContrib.cid);
            expect(closeVotes[0]).to.equal(author.addr);
            expect(finalContrib.state).to.equal(StorylineState.OPEN);
            closeVotes = await story.voteToDraft(finalContrib.cid, {from: author2.addr});
            expect(closeVotes[1]).to.equal(author2.addr);
            expect(finalContrib.state).to.equal(StorylineState.DRAFTING);
        })

        it('prevents non-leader authors from contributing to a closed storyline', async () => {
            await expect(story.contribute(finalContrib.cid, {from:author.addr})).to.be.revertedWith("Can't contribute to the storyline because it has been closed");
        })

        it('Moves the storyline to the voting phase when the storyline leader publishes the final draft', async () => {
            const finalContributionCID = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKoEi";
            const storylineLeader = await story.storylineLeader();
            expect(storylineLeader).to.equal(author); // because author made the most contributions to this storyline
            await story.contribute(finalContributionCID, finalContrib, {from:storylineLeader.addr})
            const contributions = await story.getContributions();
            finalDraftContrib = contributions[finalContributionCID];
            expect(finalContrib.state).to.equal(StorylineState.VOTING);
            expect(finalDraftContrib.state).to.equal(StorylineState.VOTING);
        })

        it('publishes a storyline when a majority of authors vote to do so', async () => {
            await story.voteToPublish(finalDraftContrib.cid, {from:author.addr});
            // the author of the final draft vote automatically goes to 'PUBLISH' choice
            expect(finalDraftContrib.state).to.equal(StorylineState.PUBLISHED);
            expect(finalContrib.state).to.equal(StorylineState.PUBLISHED);
            const publishedStories = await story.publishedStories();
            expect(publishedStories.length).to.equal(1);
        })
    })

    it('rewards author with reputation for derived works', async () => {
        expect(author.reputation).to.equal(0);
        await story.contribute(contributionCID, rootStoryCID, {from:author.addr});
        await story.contribute(contributionCID2, contributionCID, {from:author2.addr});
        expect(author.reputation).to.equal(1);
    })

    it('doesn\'t reward author for self-derived works', async () => {
        expect(author.reputation).to.equal(0);
        await story.contribute(contributionCID, rootStoryCID, {from:author.addr});
        await story.contribute(contributionCID2, contributionCID, {from:author.addr});
        expect(author.reputation).to.equal(0);
    })

    it('prevents author from submitting more than one entry to a contribution', async () => {
        await story.contribute(contributionCID, rootStoryCID, {from:author.addr});
        await story.contribute(contributionCID2, contributionCID, {from:author.addr});
        await expect(story.contribute(contributionCID3, contributionCID, {from:author.addr})).to.be.revertedWith("cannot submit more than one entry to a contribution");
    })

    it('prevents resubmissions of the same CID', async () => {
        await story.contribute(contributionCID, {from:author.addr});
        await expect(story.contribute(contributionCID, {from:author.addr})).to.be.revertedWith("cannot resubmit the same content");
    });
});
