import { ethers } from "hardhat";

async function main() {

  console.log("Deploying Library Storyline contract");
  
  const LibraryStorylineFactory = await ethers.getContractFactory("LibraryStoryline");
  const libraryStoryline = await LibraryStorylineFactory.deploy();

  console.log("Awaiting confirmations ...");
  await libraryStoryline.deployed();
  console.log(`LibraryStoryline deployed to ${libraryStoryline.address}`);

  const StoryShare = await ethers.getContractFactory("StoryShare", {
    libraries: {
      LibraryStoryline: libraryStoryline.address
    }
  });

  console.log("Deploying StoryShare contract");
  
  const storyShare = await StoryShare.deploy();
  console.log("Awaiting confirmations ...");
  await storyShare.deployed();
  console.log(`StoryShare deployed to ${storyShare.address}`);
  return storyShare.address;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
