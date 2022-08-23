require("dotenv").config();
const privateKeys = process.env["PRIVATE_KEYS"].split(",");
const infuraProjectId = process.env["INFURA_PROJECT_ID"];
const HDWalletProvider = require("@truffle/hdwallet-provider");
// const customProvider = process.env["CUSTOM_NETWORK_URL"]
// const customNetworkId = process.env["CUSTOM_NETWORK_ID"]
// const customChainId = process.env["CUSTOM_CHAIN_ID"]

module.exports = {
  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.15", // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {
        // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200,
        },
        evmVersion: "london",
      },
    },
  },
  networks: {
    development: { // Network name
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
    },
    goerli: { // Network name
      provider: () =>
        new HDWalletProvider({
          privateKeys,
          providerOrUrl: `https://goerli.infura.io/v3/${infuraProjectId}`,
        }),
      network_id: 5,
      chain_id: 5,
    },
    // custom_network: { // Network name
    //   provider: () =>
    //     new HDWalletProvider({
    //       privateKeys,
    //       providerOrUrl: customProvider,
    //     }),
    //   network_id: customNetworkId,
    //   chain_id: customChainId,
    // },
  },
};
