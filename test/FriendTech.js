const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("FriendTech", function () {
  async function deployContract() {
    const ONE_GWEI = 1_000_000_000;
    const amount = ONE_GWEI;

    const [owner, ...otherAccount] = await ethers.getSigners();

    const FriendTechSharesV2 = await ethers.getContractFactory(
      "FriendTechSharesV2"
    );
    const friendTech = await FriendTechSharesV2.deploy({
      value: amount,
    });

    return { friendTech, amount, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should be deploy", async function () {
      const { friendTech, owner, otherAccount } = await loadFixture(
        deployContract
      );
      console.log({ friendTech, owner, otherAccount });
    });
  });
});
