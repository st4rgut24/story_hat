import { ethers } from "hardhat";

async function main() {
  const StoryShare = await ethers.getContractFactory("StoryShare");
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
