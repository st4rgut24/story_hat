import { createStory } from "./createStory";
import { deploy } from "./deploy";
import { voteToDraft } from "./voteDraft";
import { contribute } from "./contribute";
import { getSigners } from "./getSigners";
import { EXPOSED_KEY, EXPOSED_KEY_2 } from "../hardhat.config";

/**
 * The story creator immediately votes to draft a story, only the owner's vote is required to send it to drafting stage
 */
async function main() {
    const signers = await getSigners([EXPOSED_KEY, EXPOSED_KEY_2]);
    const storyCreator = signers[0]; 
    const rootCID = "Qmd4cSKJdbjiRWRbtTq13AdWAPN19zQgArgcvKkfQvhP7r";
    
    const storyShareAddress = await deploy();
    const storyAddress = await createStory(storyShareAddress, rootCID, storyCreator);
    
    if (process.argv.length < 3){
        throw new Error("missing multiple or single contribution flag");
    }
    const isSingleContrib = process.argv[2];
    if (isSingleContrib === "true") {
        console.log("is single contribution. requires a single vote of owner to draft");
        await voteToDraft(storyAddress, rootCID, storyCreator);
    }
    else {
        console.log("is multiple contribution. requires two unique votes to draft");
        const cid = "QmdRfF6iBUdKGPXYiN3vckH2RGCkcbrT6dmCpZM4ZKXi5t";
        const otherContributor = signers[1];
        await contribute(storyAddress, cid, rootCID, otherContributor);
        await voteToDraft(storyAddress, cid, otherContributor);
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
