require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.26",
  networks: {
    mainnet: {
      url: vars.get("MAINNET_GATEWAY_URL"),
      accounts: [vars.get("MAINNET_ACCOUNT_PRIVATE_KEY")],
    },
  },
  etherscan: {
    apiKey: vars.get("ETHERSCAN_API_KEY"),
  },
};
