const Staking = artifacts.require("Stake");
const Token = artifacts.require("Token");

module.exports = function (deployer, network, accounts) {
  // constructor(address _token, address _companyWallet)
  // Using the deployer's address as 'company wallet'
  deployer.deploy(Staking, Token.address, accounts[0]);
};
