const Token = artifacts.require("Token");

require("dotenv").config();
const TOKEN_SUPPLY = process.env.TOKEN_SUPPLY;

module.exports = function (deployer, _, accounts) {
  // Have to add 'from' as without that 'overwrite' is not being interpreted
  // https://github.com/trufflesuite/truffle/issues/2843
  deployer.deploy(Token, TOKEN_SUPPLY, {
    from: accounts[0],
    overwrite: false,
  });
};
