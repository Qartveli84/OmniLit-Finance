require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const PRIVATE_KEY = (process.env.PRIVATE_KEY || "").trim();

module.exports = {
  solidity: {
    version: "0.8.26",
    settings: {
      optimizer: { enabled: true, runs: 200 }
    }
  },
  networks: {
    litvm_testnet: {
      url: "https://rpc.testnet.liteforge.zeeve.net/",
      chainId: 4441,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : []
    }
  },
  etherscan: {
    apiKey: {
      litvm_testnet: "empty"
    },
    customChains: [
      {
        network: "litvm_testnet",
        chainId: 4441,
        urls: {
          apiURL: "https://explorer.testnet.liteforge.zeeve.net/api",
          browserURL: "https://explorer.testnet.liteforge.zeeve.net"
        }
      }
    ]
  }
};
