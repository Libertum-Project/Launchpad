const PAYEES = [
  "0x16af037878a6cAce2Ea29d39A3757aC2F6F7aac1", //mia - proyecto
  "0x2F09F2124a141057bfD7D3453EEECa25628A450a", //Luis - libertum
];

const SHARES = [90, 10]; //100%

module.exports = [
  60, //percentage for LP
  "0x2b0E9B57B3543e182fEE9aDA6c175be9828640E9", //usdt address
  "0x3f0BF9dDeeA948175D22B1DdEfe26Da18Ef0c151", //project token address
  2, //price project token
  1, //min amount
  PAYEES, //partners
  SHARES, //shares
];

//npx hardhat verify --constructor-args arguments.js DEPLOYED_CONTRACT_ADDRESS

/* npx hardhat verify 0x3A324e9D7D85Fa035aecc7c74c026d46db31F4AA 
"50" "0x387d5C7587db0531580c3F9799146f5340d71175" 
"0x8BCa90c3930F2129CB1ffddCf26c25a0F50AcB4a" "2" "1" 
["0xA3286628134baD128faeef82F44e99AA64085C94","0xc85eE321199BaB137F0885F045B0f0Ebd151bD11","0x5875da5854c2adAdBc1a7a448b5B2A09b26Baff8","0xc7203EfeB54846C149F2c79B715a8927F7334e74"] 
[50,30,10,10] --network bsc_testnet --show-stack-traces */
