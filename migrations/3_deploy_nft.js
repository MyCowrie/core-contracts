const NFT = artifacts.require("NFT");

require("dotenv").config();
const NFT_SUPPLY = process.env.NFT_SUPPLY;

module.exports = function (deployer) {
  deployer.deploy(NFT, NFT_SUPPLY);
};
