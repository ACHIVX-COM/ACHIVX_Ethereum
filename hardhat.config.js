require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.26",
  networks: {
    mainnet: {
      url: vars.get("MAINNET_GATEWAY_URL"),
      accounts: [vars.get("MAINNET_ACCOUNT_PRIVATE_KEY")],
    },
    arbitrumOne: {
      url: "https://arb1.arbitrum.io/rpc",
      accounts: [vars.get("MAINNET_ACCOUNT_PRIVATE_KEY")],
    },
    avalancheMain: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts: [vars.get("MAINNET_ACCOUNT_PRIVATE_KEY")],
    },
    polygonMain: {
      url: "https://polygon-bor-rpc.publicnode.com",
      accounts: [vars.get("MAINNET_ACCOUNT_PRIVATE_KEY")],
    },
    optimismMain: {
      url: "https://optimism-rpc.publicnode.com",
      accounts: [vars.get("MAINNET_ACCOUNT_PRIVATE_KEY")],
    },
    baseMain: {
      url: "https://base-rpc.publicnode.com",
      accounts: [vars.get("MAINNET_ACCOUNT_PRIVATE_KEY")],
    },
    bnbSmartChainMain: {
      url: "https://bsc-rpc.publicnode.com",
      accounts: [vars.get("MAINNET_ACCOUNT_PRIVATE_KEY")],
    },
    opBnbMain: {
      url: "https://opbnb-rpc.publicnode.com",
      accounts: [vars.get("MAINNET_ACCOUNT_PRIVATE_KEY")],
    },
  },
  etherscan: {
    apiKey: vars.get("ETHERSCAN_API_KEY"),
  },
};
