const hre = require("hardhat");
const { BigNumber } = require("ethers");

async function main() {
  const owner = "0xA3286628134baD128faeef82F44e99AA64085C94"; //t2
  const PAYEES = [
    "0x16af037878a6cAce2Ea29d39A3757aC2F6F7aac1", //mia - proyecto
    "0x2F09F2124a141057bfD7D3453EEECa25628A450a", //Luis - libertum
  ];

  const SHARES = [90, 10]; //100%

  //recogimos 30usdt
  //60% al LP --> 18usdt
  //sobran 12usdt (santiago y luis)
  //santiago recibe 10.8
  //luis recibiria 8usdt 1.2

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
  const PERCENTAGE_FOR_LP = 60;
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
