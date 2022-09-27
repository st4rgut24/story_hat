import { ethers } from "hardhat";
import * as StoryJson from "../artifacts/contracts/StoryShare.sol/StoryShare.json";
import { EXPOSED_KEY } from "../hardhat.config";
import { StoryShare } from "../typechain-types";
import { ethers as ethers_io } from "ethers";
import { checkBalance } from "./getSigners";

export async function createStory(storyShareAddress: string, cid: string, signer: ethers_io.Wallet) {
  await checkBalance(signer);
  // if (process.argv.length < 3) {
  //   throw new Error("Provide the address of the story contract");
  // }
  // const storyContractAddress = process.argv[2];
  // const StoryContract: StoryShare = await ethers.getContractAt(StoryJson.abi, storyContractAddress) as StoryShare;
  const StoryContract: StoryShare = await ethers.getContractAt(StoryJson.abi, storyShareAddress) as StoryShare;
  // if (process.argv.length < 4) {
  //   throw new Error("Provide the cid of the root contribution");
  // }
  // const cid = process.argv[3];
  console.log("Contributing to story");
  console.log("bytes array", ethers.utils.toUtf8Bytes(cid));
  const bytesLikeCID = ethers.utils.toUtf8Bytes(cid);
  const bytes32Genre = ethers.utils.formatBytes32String('horror');
  const tx = await StoryContract.createStory(bytesLikeCID, 'title', 'summary', bytes32Genre);
  console.log("Awaiting confirmations ...");
  await tx.wait();
  console.log("Transaction confirmed");
  const storyContractAddress = await StoryContract.getStoryByCID(bytesLikeCID);
  await tx.wait();
  console.log('story cid', storyContractAddress);
  return storyContractAddress;
  
}

// // We recommend this pattern to be able to use async/await everywhere
// // and properly handle errors.
// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });
