// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { getSavedContractAddresses, saveContractAddress } = require('./utils')

main = async () => {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  
  [deployer] = await ethers.getSigners();
  console.log('deployer = ', deployer.address);

  let USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  // Deploy AddressManager contract and set deployer as a manager
  const AddressManager = await hre.ethers.getContractFactory("AddressManager");
  const addressManager = await upgrades.deployProxy(AddressManager, [deployer.address]);
  await addressManager.deployed();

  console.log("AddressManager contract deployed to:", addressManager.address);
  saveContractAddress(hre.network.name, 'AddressManager', addressManager.address);

  // Deploy Treasury contract and set it to AddressManager
  const Treasury = await hre.ethers.getContractFactory("Treasury");
  const treasury = await upgrades.deployProxy(Treasury, [addressManager.address]);
  await treasury.deployed();
  addressManager.setTreasuryContract(treasury.address);
  
  console.log("Treasury contract deployed to:", treasury.address);
  saveContractAddress(hre.network.name, 'Treasury', treasury.address);

  // Deploy YearnUSDCStrategy contract and set it to AddressManager
  const YearnUSDCStrategy = await hre.ethers.getContractFactory("YearnUSDCStrategy");
  const yearnUSDCStrategy = await upgrades.deployProxy(YearnUSDCStrategy, [addressManager.address]);
  await yearnUSDCStrategy.deployed();
  addressManager.setYearnUSDCStrategy(yearnUSDCStrategy.address);
  
  console.log("YearnUSDCStrategy contract deployed to:", yearnUSDCStrategy.address);
  saveContractAddress(hre.network.name, 'YearnUSDCStrategy', yearnUSDCStrategy.address);

  // Deploy Banker contract and set it to AddressManager
  let mintDepositPercentage = 0;  // 100% MaxBanker
  let redemptionDelaytime = 60*60*24*7; // 7 days
  const Banker = await hre.ethers.getContractFactory("Banker");
  const banker = await upgrades.deployProxy(Banker, [addressManager.address, mintDepositPercentage, redemptionDelaytime]);
  await banker.deployed();
  addressManager.setBankerContract(banker.address);
  
  console.log("Banker contract deployed to:", banker.address);
  saveContractAddress(hre.network.name, 'Banker', banker.address);

  // Allow USDC in Treasury
  treasury.allowToken(USDC_ADDRESS);

  // Add strategy to Banker
  banker.addStrategy(treasury.address, 0, 500); // InsuranceAP = 0, DesiredAssetAP = 5%
  banker.addStrategy(yearnUSDCStrategy.address, 0, 9500); // InsuranceAP = 0, DesiredAssetAP = 5%

};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
