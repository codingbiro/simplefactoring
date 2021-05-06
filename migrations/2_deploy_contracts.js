var SimpleFactoring = artifacts.require("./SimpleFactoring.sol");
module.exports = function(deployer) {
  deployer.deploy(SimpleFactoring);
};