import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'hardhat-contract-sizer';

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  networks: {
    goerli: {
      url: 'https://goerli.infura.io/v3/14c911050f2b4ae792218579902f1a6c',
      accounts: ['833e93e36d1e1502620de60d0938d0e6fae115b']
    },
    hardhat: {
      chainId: 5 // 1337
    }
 }
};

export default config;
