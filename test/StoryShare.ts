const { expect } = require("chai");

import {StoryShare, Story} from "../artifacts/contracts/StoryShare.sol/StoryShare.json"

describe('StoryShare', async () => {    
  const storyCID = "bafykbzacea5alvq742sh5aakjhbhychtgs3ihol7dk4t2xtiye32vxz2tyd3m";
  const otherStoryCID = "safykbzacea5alvq742sh5aakjhbhychtgs3ihol7dk4t2xtiye32vxz2tyd3m";
  const genre = 'thriller';
  const summary = "a thriller about a boy born with wings";
  
  let storyShare: StoryShare;

  beforeEach(async () => {
    storyShare = new StoryShare();
  })
  
  it('should add a new story', async () => {
    await storyShare.createStory(storyCID, summary, genre);
    const story = await StoryShare.getStoryByCID(storyCID)
    expect(story.cid).to.equal(storyCID);
  });

  it('reverts if getting a story that does not exist', async () => {
    await expect(StoryShare.getStoryByCID(storyCID)).to.be.revertedWith('the story does not exist');
  });

  it('should not add a duplicate story', async () => {
    await expect(storyShare.createStory(storyCID, summary, genre)).to.be.revertedWith('cannot add a duplicate story cid');
  });

  it('should set the latest story as the feature story if not set by community', async () => {
    await storyShare.createStory(storyCID, summary, genre);
    const featuredStory = await storyShare.featuredStory();
    await expect(featuredStory.cid).to.equal(storyCID);
  })

  it('should not set the latest story as the feature story if set by community', async () => {
    await storyShare.setFeaturedStoryCID(storyCID);
    await storyShare.createStory(otherStoryCID, summary, genre);
    const featuredStory = await storyShare.featuredStory();
    await expect(featuredStory.cid).to.equal(storyCID);
  })  
});
