require("@nomicfoundation/hardhat-toolbox");

require("dotenv").config();

const { PRIVATE_KEY, API_BSC } = process.env;

module.exports = {
  solidity: "0.8.10",
  defaultNetwork: "hardhat",
  networks: {
    bsc_testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: API_BSC,
  },
};
