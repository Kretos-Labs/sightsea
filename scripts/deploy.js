// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60;

  const lockedAmount = hre.ethers.parseEther("0.001");
  const friendTechAmount = hre.ethers.parseEther("0.05");

  const initialSupply = 1000;
  const pointTokenAmount = hre.ethers.parseEther("0.1");

  const lock = await hre.ethers.deployContract("Lock", [unlockTime], {
    value: lockedAmount,
  });

  const friendTech = await hre.ethers.deployContract("FriendTechSharesV2", {
    value: friendTechAmount,
  });

  const pointToken = await hre.ethers.deployContract(
    "PointToken",
    [initialSupply],
    {
      value: pointTokenAmount,
    }
  );

  await lock.waitForDeployment();
  await friendTech.waitForDeployment();
  await pointToken.waitForDeployment();

  console.log(
    `Lock with ${ethers.formatEther(
      lockedAmount
    )}ETH and unlock timestamp ${unlockTime} deployed to ${lock.target}`
  );

  console.log(
    `FriendTechSharesV2 with ${ethers.formatEther(
      friendTechAmount
    )}ETH deployed to ${friendTech.target}`
  );

  console.log(
    `PointToken with ${ethers.formatEther(pointTokenAmount)}ETH deployed to ${
      pointToken.target
    }`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
