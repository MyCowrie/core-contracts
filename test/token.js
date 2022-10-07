const Token = artifacts.require("Token");
const assert = require("assert");

require("dotenv").config();

contract("Token", (accounts) => {
  const BN = web3.utils.BN;

  it("should not be able to mint token over supply cap", async () => {
    const tokenInstance = await Token.deployed();

    await tokenInstance.setVestingAddress(await tokenInstance.owner());

    const supply = await tokenInstance.totalSupply();
    const remaining = (await tokenInstance.cap()).sub(supply);
    const thirdOfLeft = remaining.div(new BN(3));

    await tokenInstance.mint(accounts[0], thirdOfLeft);
    await tokenInstance.mint(accounts[1], thirdOfLeft);
    await tokenInstance.mint(accounts[2], thirdOfLeft);
    // Minting cap must be reached now

    assert.rejects(async () => {
      await tokenInstance.mint(accounts[3], new BN('100', await tokenInstance.decimals().toString()));
    }, Error);
  });
});
