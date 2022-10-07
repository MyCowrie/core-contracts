const VestingTest = artifacts.require("VestingTest");
const Token = artifacts.require("Token");
const assert = require("assert");

require("dotenv").config();

contract("Token", (accounts) => {
  const BN = web3.utils.BN;

  it("total vested amount must not cross the limit", async () => {
    const totalVestingTokens = new BN(1000, 18); // setting 1000 tokens vesting limit
    const vestingInstance = await VestingTest.new(Token.address, 30, totalVestingTokens);

    // function addBeneficiary(
    //   address _beneficiary,
    //   uint256 _amount,
    //   bool _haveSubWallets,
    //   bool _startFromNow,
    //   bool _isSAPD
    // )
    await vestingInstance.addBeneficiary(accounts[0], totalVestingTokens.div(3), false, true, false);
    await vestingInstance.addBeneficiary(accounts[0], totalVestingTokens.div(3), false, true, false);
    await vestingInstance.addBeneficiary(accounts[0], totalVestingTokens.div(3), false, true, false);

    assert.rejects(async () => {
      await vestingInstance.addBeneficiary(accounts[0], totalVestingTokens.div(3), false, true, false);
    }, Error);
  });
});
