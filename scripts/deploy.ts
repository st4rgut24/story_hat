import { ethers } from "hardhat";

async function main() {
  const LibraryStorylineFactory = await ethers.getContractFactory("LibraryStoryline");
  const libraryStoryline = await LibraryStorylineFactory.deploy();
  await libraryStoryline.deployed();
  console.log(`LibraryStoryline deployed to ${libraryStoryline.address}`);

  const StoryShare = await ethers.getContractFactory("StoryShare", {
    libraries: {
      LibraryStoryline: libraryStoryline.address
    }
  });
  const storyShare = await StoryShare.deploy();

  await storyShare.deployed();

  console.log(`StoryShare deployed to ${storyShare.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
