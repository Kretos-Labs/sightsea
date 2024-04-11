// migrations/deploy.js
// SPDX-License-Identifier: MIT
const Contract = artifacts.require("mETH");

module.exports = function(deployer) {
  deployer.deploy(Contract);
};