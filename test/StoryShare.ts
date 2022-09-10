const { expect } = require("chai");
import { Story, StoryShare } from "../typechain-types";
import { ethers } from "hardhat";

describe('StoryShare', async () => {    
  const storyCID = "bafykbzacea5alvq742sh5aakjhbhychtgs3ihol7dk4t2xtiye32vxz2tyd3m";

  let storyShare: StoryShare;


  const StoryShareFactory = await ethers.getContractFactory("StoryShare");

  beforeEach(async () => {
    storyShare = await StoryShareFactory.deploy() as StoryShare;
  })
  
  it('should add a new story', async () => {
    await storyShare.createStory(storyCID);
    const storyAddr = await storyShare.getStoryByCIDPublic(storyCID);
    const storyContract = await ethers.getContractAt("Story", storyAddr);
    const story = await storyContract.deployed() as Story;
    expect(story.cid).to.equal(storyCID);
  });

  it('reverts if getting a story that does not exist', async () => {
    await expect(storyShare.getStoryByCID(storyCID)).to.be.revertedWith('the story does not exist');
  });

  it('should not add a duplicate story', async () => {
    await expect(storyShare.createStory(storyCID)).to.be.revertedWith('cannot add a duplicate story cid');
  });

  it('should set the latest story as the feature story if not set by community', async () => {
    await storyShare.createStory(storyCID);    
    const featuredStoryAddr = await storyShare.featuredStory();
    await expect(storyCID).to.equal(featuredStoryAddr);
  })

  it('should not set the latest story as the feature story if set by community', async () => {
    const otherStoryCID = "safykbzacea5alvq742sh5aakjhbhychtgs3ihol7dk4t2xtiye32vxz2tyd3m";

    await storyShare.createStory(storyCID);    
    await storyShare.setFeaturedStoryCID(storyCID);
    await storyShare.createStory(otherStoryCID);    
    const featuredStoryAddr = await storyShare.featuredStory();

    await expect(featuredStoryAddr).to.not.equal(otherStoryCID);
    await expect(featuredStoryAddr).to.equal(storyCID);
  })  
});
