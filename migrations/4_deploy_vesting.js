const Vesting = artifacts.require("TokenVesting");
const NFT = artifacts.require("NFT");
const Token = artifacts.require("Token");

require("dotenv").config();
const VESTING_AMOUNT = process.env.VESTING_AMOUNT;
const LAST_PRICE = process.env.LAST_PRICE;

module.exports = async function (deployer) {
  // constructor(
  //   address _tokenAddr,
  //   uint256 _lastMarkedPrice,
  //   uint256 _totalVestingTokens
  // )
  await deployer.deploy(Vesting, Token.address, LAST_PRICE, VESTING_AMOUNT);
  
  const instance = await Vesting.deployed();
  await instance.setNFTAddress(NFT.address);
};
