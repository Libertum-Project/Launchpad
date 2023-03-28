const hre = require("hardhat");
const { BigNumber } = require("ethers");

async function main() {
  let owner = "0xc85eE321199BaB137F0885F045B0f0Ebd151bD11";
  let payees = [
    owner,
    "0xA3286628134baD128faeef82F44e99AA64085C94",
    "0x5875da5854c2adAdBc1a7a448b5B2A09b26Baff8",
  ];
  let shares = [50, 25, 25];
  let decimals = 10 ** 18;

  //deploy the tokens
  const usdt = await (
    await (await hre.ethers.getContractFactory("USDT")).deploy()
  ).deployed();
  const project1token = await (
    await (await hre.ethers.getContractFactory("Project1")).deploy()
  ).deployed();
  console.log(`USDT deployed to: ${usdt.address}`);
  console.log(`Project1 deployed to: ${project1token.address}`);

  //deploy the Launchpad
  const Launchpad = await hre.ethers.getContractFactory("Launchpad");
  const launchpad = await Launchpad.deploy(
    50, //percentageForLP
    usdt.address, //IERC20 mainCurrency
    project1token.address, ///IERC20 projectToken
    20, //projectToken Price in USDT
    2, //minimum Amount to purchase of ProjectToken
    payees,
    shares
  );

  await launchpad.deployed();
  console.log(`Launchpad deployed to: ${launchpad.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
