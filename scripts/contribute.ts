import { ethers } from "hardhat";
import * as StoryJson from "../artifacts/contracts/StoryShare.sol/Story.json";
import { Story } from "../typechain-types";
import { checkBalance } from "./getSigners";
import { ethers as ethers_io } from "ethers";

export async function contribute(storyAddress: string, cid: string, prevCID: string, signer: ethers_io.Wallet) {
  await checkBalance(signer);

  // if (process.argv.length < 3) {
  //   throw new Error("Provide the address of the story contract");
  // }
  // const storyContractAddress = process.argv[2];
  // const StoryContract: StoryShare = await ethers.getContractAt(StoryJson.abi, storyContractAddress) as StoryShare;
  const StoryContract: Story = await ethers.getContractAt(StoryJson.abi, storyAddress) as Story;
  const StoryContractOther = StoryContract.connect(signer); // connect as someone else
  // if (process.argv.length < 4) {
  //   throw new Error("Provide the cid of the root contribution");
  // }
  // const cid = process.argv[3];
  console.log("Contributing to previous story cid", prevCID);
  const bytesLikeCurCID = ethers.utils.toUtf8Bytes(cid);
  const bytesLikePrevCID = ethers.utils.toUtf8Bytes(prevCID);
  console.log("contribute with address", signer.address);
  const tx = await StoryContractOther.contribute(bytesLikeCurCID, bytesLikePrevCID, {from: signer.address});
  console.log("Awaiting confirmations ...");
  await tx.wait();
  
}

// // We recommend this pattern to be able to use async/await everywhere
// // and properly handle errors.
// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });
