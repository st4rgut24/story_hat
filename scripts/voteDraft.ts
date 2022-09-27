import { ethers } from "hardhat";
import * as StoryContractAbi from "../artifacts/contracts/StoryShare.sol/Story.json";
import { EXPOSED_KEY } from "../hardhat.config";
import { Story } from "../typechain-types";
import { ethers as ethers_io } from "ethers";
import { checkBalance } from "./getSigners";

export async function voteToDraft(storyContractAddress: string, cid: string, signer: ethers_io.Wallet) {
  await checkBalance(signer);

  // if (process.argv.length < 3) {
  //   throw new Error("Provide the address of the story contract");
  // }
  // const storyContractAddress = process.argv[2];
  // const StoryContract: Story = await ethers.getContractAt(StoryContractAbi.abi, storyContractAddress) as Story;
  const StoryContract: Story = await ethers.getContractAt(StoryContractAbi.abi, storyContractAddress) as Story;
  // if (process.argv.length < 4) {
  //   throw new Error("Provide the cid of the contribution");
  // }
  // const cid = process.argv[3];
  // const cid = "Qmd4cSKJdbjiRWRbtTq13AdWAPN19zQgArgcvKkfQvhP7r";
  const bytesLikeCID = ethers.utils.toUtf8Bytes(cid)
  console.log("Voting for the story");

  const tx = await StoryContract.voteToDraft(bytesLikeCID)
  await tx.wait();
  console.log("Awaiting confirmations ...");
}

// // We recommend this pattern to be able to use async/await everywhere
// // and properly handle errors.
// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });
