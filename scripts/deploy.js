const hre = require("hardhat");
const { BigNumber } = require("ethers");

async function main() {
  const owner = "0xA3286628134baD128faeef82F44e99AA64085C94"; //t2
  const PAYEES = [
    owner, //t2
    "0xc85eE321199BaB137F0885F045B0f0Ebd151bD11", //t1
    "0x5875da5854c2adAdBc1a7a448b5B2A09b26Baff8", //t3
    "0xc7203EfeB54846C149F2c79B715a8927F7334e74", //t4
  ];
  const SHARES = [50, 30, 10, 10];
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

  //variables for the Launchpad constructor
  const PERCENTAGE_FOR_LP = 50;
  const USDT_ADDRESS = usdt.address;
  const PROJECT_TOKEN_ADDRESS = project1token.address;
  const PROJECT_TOKEN_PRICE_IN_USDT = 2;
  const MIN_AMOUNT_TO_PURCHASE = 1;
  //deploy the Launchpad
  const Launchpad = await hre.ethers.getContractFactory("LaunchpadLibertum");
  const launchpad = await Launchpad.deploy(
    PERCENTAGE_FOR_LP,
    USDT_ADDRESS,
    PROJECT_TOKEN_ADDRESS,
    PROJECT_TOKEN_PRICE_IN_USDT,
    MIN_AMOUNT_TO_PURCHASE,
    PAYEES,
    SHARES
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
