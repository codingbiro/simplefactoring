const SimpleFactoring = artifacts.require('./SimpleFactoring.sol');
module.exports = (deployer) => {
  deployer.deploy(SimpleFactoring);
};
