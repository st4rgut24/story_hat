import { ethers } from "hardhat";
import { ethers as ethers_io} from "ethers";

export async function getSigners (keyArr: string[]) {

    let signerArr: ethers_io.Wallet[] = [];
    const provider = ethers.providers.getDefaultProvider('http://localhost:8545');

    keyArr.forEach(async (key) => {
        const wallet = new ethers.Wallet(key);
        const signer = wallet.connect(provider);
        signerArr.push(signer);
    })
    return signerArr;
}

export async function checkBalance(signer: ethers_io.Wallet){
    const balanceBN = await signer.getBalance();
    const balance = Number(ethers.utils.formatEther(balanceBN));
    console.log('balance is', balance);
    if (balance < 0.01) {
      throw new Error("Not enough ether");
    }
}