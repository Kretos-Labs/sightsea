// migrations/deploy.js
// SPDX-License-Identifier: MIT
const Contract = artifacts.require("SightseaSharesV1");

module.exports = function(deployer) {
  deployer.deploy(Contract);
};