const NFT = artifacts.require("NFT");
const assert = require("assert");

require("dotenv").config();
const NFT_SUPPLY = process.env.NFT_SUPPLY;

contract("NFT", (accounts) => {
  it("cap should match the required supply cap", async () => {
    const nftInstance = await NFT.deployed();
    const supplyCap = (await nftInstance.TOTAL_SUPPLY_CAP()).toString();

    assert.equal(
      supplyCap,
      NFT_SUPPLY,
      "NFT supply cap did not match required cap"
    );
  });

  it("should not be able to mint nft over supply cap", async () => {
    const nftInstance = await NFT.deployed();
    const supplyCap = (await nftInstance.TOTAL_SUPPLY_CAP()).toString();

    for (let i = 1; i <= Number(supplyCap); i++) {
      // Hardcoding fee numerator to 5%
      await nftInstance.mintTo(accounts[i % accounts.length], 5000);
    }

    assert.rejects(async () => {
      // Minting in first account, fee numerator set to 0.5%
      await nftInstance.mintTo(accounts[0], 5000);
    }, Error);
  });
});
