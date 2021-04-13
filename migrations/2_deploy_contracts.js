//const ConvertLib = artifacts.require("ConvertLib");
const KINARY = artifacts.require("Kinary");
const SAMPLE = artifacts.require("SampleToken");


module.exports = function(deployer) {
  // deployer.deploy(ConvertLib);
  // deployer.link(ConvertLib, KINARY);
  // deployer.link()
  deployer.deploy(SAMPLE)
  deployer.deploy(KINARY);
};
