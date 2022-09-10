import { Story } from "../typechain-types";
import { StoryShare } from "../typechain-types";

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
        DRAFTING_END,
        FINAL_REVIEW,
        PUBLISHED
    }


    const contributionCID = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKoc";
    const contributionCID2 = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKod";
    const contributionCID3 = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKoe";
    const contributionCID4 = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKof";
    const contributionCID5 = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKog";
    const contributionCIDList = [contributionCID, contributionCID2, contributionCID3, contributionCID4, contributionCID5];

    const StoryShareFactory = await ethers.getContractFactory("StoryShare");
    const StoryFactory = await ethers.getContractFactory("Story");

    var storyShare: StoryShare;
    var story: Story;

    beforeEach(async () => {
        storyShare = await StoryShareFactory.deploy() as StoryShare;
        story = await StoryFactory.deploy(rootStoryCID, storyShare.address) as Story;

        await storyShare.createAuthor(authorAddr, username, profilePic);
        await storyShare.createAuthor(authorAddr2, username2, profilePic2);
    })

    it('assigns the first contribution', async () => {
        await story.contribute(contributionCID, rootStoryCID, {from:authorAddr});
        const firstContributionCID = await story.cid();
        expect(firstContributionCID).to.equal(contributionCID);
    })

    it('assigns subsequent contributions', async () => {
        await story.contribute(contributionCID, rootStoryCID, {from:authorAddr});        
        await story.contribute(contributionCID2, contributionCID, {from:authorAddr});
        const contribution = await story.getContribution(contributionCID2);        
        const firstContrib = await story.getContribution(contributionCID);
        // sets prev contrib pointer
        expect(contribution.prevCID).to.equal(contributionCID);
        // sets next contrib pointer
        expect(firstContrib.nextCIDs).length.to.equal(1);
        expect(firstContrib.nextCIDs[0]).to.equal(contributionCID2);
    })

    it('bookmark a contribution', async () => {
        await story.contribute(contributionCID, rootStoryCID, {from:authorAddr});
        await story.bookmark(contributionCID);
        const savedCID = await story.getSavedCID();
        expect(savedCID).to.equal(contributionCID);
    })

    it('links a contribution to its author', async () => {
        await story.contribute(contributionCID, rootStoryCID, {from:authorAddr});
        const contribution = await story.getContribution(contributionCID);
        expect(contribution.authorAddr).to.equal(authorAddr);
    });

    describe('a storyline', async () => {

        const publishContributionCID = "QmSg55nGoQmSiYdkyS2gEz8vMPJ3U7UGJa9ANenPfbFKoEi";

        for (let i=0;i<contributionCIDList.length;i++){
            let prevCid = i === 0 ? rootStoryCID : contributionCIDList[i-1];
            let storylineAuthorAddr = i%2 == 0 ? authorAddr : authorAddr2;
            await story.contribute(contributionCIDList[i], prevCid, {from:storylineAuthorAddr});            
        }

        const finalContrib = await story.getContribution(contributionCIDList[contributionCIDList.length - 1]);
        let finalDraftContrib: { state: any; cid: any; }; // the contribution that includes the whole storyline

        it('creates a path from leaf node to root node', async () => {     
            await expect(story.getStoryline(finalContrib.cid)).to.emit(story, "storylineEvent").withArgs(""); 
            // for (let i=0;i<contributionCIDList.length;i++){
            //     expect(actualContribList[i]).to.equal(contributionCIDList[i]);            
            // }
        })

        it('reverts when a non-author tries to close a storyline', async () => {
            const outsiderAddr = "0xB620c98D8S9F098bC38Ae9c7531a34ec8d3F06CB";        
            await expect(story.voteToDraft(finalContrib.cid, {from: outsiderAddr})).to.be.revertedWith("A non-author cannot vot to close a storyline");
        })

        it("closes a storyline to public submissions when a majority of authors vote", async () => {
            await story.voteToDraft(finalContrib.cid, {from: authorAddr});
            await story.voteToDraft(finalContrib.cid);
            let draftVoters = await story.getDraftVotes(finalContrib.cid);
            expect(draftVoters[0]).to.equal(authorAddr);
            let contrib = await story.getContribution(contributionCIDList[contributionCIDList.length - 1]);
            expect(contrib.state).to.equal(StorylineState.OPEN);
            await story.voteToDraft(finalContrib.cid, {from: authorAddr2});
            draftVoters = await story.getDraftVotes(finalContrib.cid);            
            expect(draftVoters[1]).to.equal(authorAddr2);
            contrib = await story.getContribution(contributionCIDList[contributionCIDList.length - 1]);
            expect(contrib.state).to.equal(StorylineState.DRAFTING);
        })

        it('prevents non-leader authors from contributing to a closed storyline', async () => {
            await expect(story.contribute(finalContrib.cid, contributionCID, {from:authorAddr})).to.be.revertedWith("Can't contribute to the storyline because it has been closed");
        })

        it('Moves the storyline to the voting phase when the storyline leader publishes the final draft', async () => {
            await expect(story.getStorylineLeader([authorAddr, authorAddr2], publishContributionCID)).to.emit(story, "storylineLeaderEvent").withArgs(authorAddr);
            await story.contribute(publishContributionCID, finalContrib.cid, {from:authorAddr})
            finalDraftContrib = await story.getContribution(publishContributionCID);
            expect(finalContrib.state).to.equal(StorylineState.DRAFTING_END);
            expect(finalDraftContrib.state).to.equal(StorylineState.FINAL_REVIEW);
        })

        it('publishes a storyline when a majority of authors vote to do so', async () => {
            await story.voteToPublish(finalDraftContrib.cid, {from:authorAddr});
            finalDraftContrib = await story.getContribution(publishContributionCID);

            // the author of the final draft vote automatically goes to 'PUBLISH' choice
            expect(finalDraftContrib.state).to.equal(StorylineState.PUBLISHED);
            expect(finalContrib.state).to.equal(StorylineState.PUBLISHED);
        })
    })

    it('rewards author with reputation for derived works', async () => {
        const author = await storyShare.getAuthorPublic(authorAddr);
        expect(author.reputation).to.equal(0);
        await story.contribute(contributionCID, rootStoryCID, {from:authorAddr});
        await story.contribute(contributionCID2, contributionCID, {from: authorAddr2});
        expect(author.reputation).to.equal(1);
    })

    it('doesn\'t reward author for self-derived works', async () => {
        const author = await storyShare.getAuthorPublic(authorAddr);
        expect(author.reputation).to.equal(0);
        await story.contribute(contributionCID, rootStoryCID, {from:authorAddr});
        await story.contribute(contributionCID2, contributionCID, {from:authorAddr});
        expect(author.reputation).to.equal(0);
    })

    it('prevents author from submitting more than one entry to a contribution', async () => {
        await story.contribute(contributionCID, rootStoryCID, {from:authorAddr});
        await story.contribute(contributionCID2, contributionCID, {from:authorAddr});
        await expect(story.contribute(contributionCID3, contributionCID, {from:authorAddr})).to.be.revertedWith("cannot submit more than one entry to a contribution");
    })

    it('prevents resubmissions of the same CID', async () => {
        await story.contribute(contributionCID, rootStoryCID, {from:authorAddr});
        await expect(story.contribute(contributionCID, rootStoryCID, {from:authorAddr})).to.be.revertedWith("cannot resubmit the same content");
    });
});
