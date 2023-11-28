const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("PointToken", function () {
  async function deployContract() {
    const ONE_GWEI = 1_000_000_000;
    const amount = ONE_GWEI;

    const [owner, ...otherAccount] = await ethers.getSigners();

    const PointToken = await ethers.getContractFactory("PointToken");
    const pointToken = await PointToken.deploy({
      value: amount,
    });

    return { pointToken, amount, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should be deploy", async function () {
      const { pointToken, owner, otherAccount } = await loadFixture(
        deployContract
      );
      console.log({ pointToken, owner, otherAccount });
    });
  });
});
