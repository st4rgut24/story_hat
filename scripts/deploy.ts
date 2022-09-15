import { ethers } from "hardhat";
// import { EXPOSED_KEY } from "../hardhat.config";

async function main() {
  // const wallet = new ethers.Wallet("3b358b0268b735c1a3cb6e63357081425ae04a7ec68dd3f83dbf019904d5cdd2");
  // const provider = ethers.providers.getDefaultProvider("goerli");
  // const signer = wallet.connect(provider);
  // const balanceBN = await signer.getBalance();
  // const balance = Number(ethers.utils.formatEther(balanceBN));
  // console.log(`Wallet balance ${balance}`);
  // if (balance < 0.01) {
  //   throw new Error("Not enough ether");
  // }

  console.log("Deploying Library Storyline contract");

  // const LibraryStorylineFactory = await new ethers.ContractFactory(
  //   LibraryStorylineJson.abi,
  //   LibraryStorylineJson.bytecode, 
  //   signer
  // );
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
  // const StoryShare = await new ethers.ContractFactory(
  //   StoryShareJson.abi,
  //   StoryShareJson.bytecode,
  //   signer
  // );
  
  const storyShare = await StoryShare.deploy();
  console.log("Awaiting confirmations ...");
  await storyShare.deployed();
  console.log(`StoryShare deployed to ${storyShare.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
