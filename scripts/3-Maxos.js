// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
const hre = require("hardhat");
const { getSavedContractAddresses, saveContractAddress, saveContractAbis } = require('./utils')

main = async () => {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  contracts = getSavedContractAddresses()[hre.network.name];

  [deployer] = await ethers.getSigners();
  console.log('deployer = ', deployer.address);

  // let USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // mainnet address
  let USDC_ADDRESS = "0x1fA02b2d6A771842690194Cf62D91bdd92BfE28d";  // mock address

  // Deploy AddressManager contract and set deployer as a manager
  const AddressManager = await hre.ethers.getContractFactory("AddressManager");
  const addressManager = await upgrades.deployProxy(AddressManager, [deployer.address]);
  await addressManager.deployed();

  console.log("AddressManager contract deployed to:", addressManager.address);
  saveContractAddress(hre.network.name, 'AddressManager', addressManager.address);
  let addressManagerArtifact = await hre.artifacts.readArtifact("AddressManager");
  saveContractAbis(hre.network.name, 'AddressManager', addressManagerArtifact.abi, hre.network.name);
  
  // Deploy Banker contract and set it to AddressManager
  let mintDepositPercentage = 0;  // 100% MaxBanker
  let redemptionDelaytime = 60*60*24*7; // 7 days
  const Banker = await hre.ethers.getContractFactory("Banker");
  const banker = await upgrades.deployProxy(Banker, [addressManager.address, mintDepositPercentage, redemptionDelaytime]);
  await banker.deployed();
  await addressManager.setBankerContract(banker.address);
  
  console.log("Banker contract deployed to:", banker.address);
  saveContractAddress(hre.network.name, 'Banker', banker.address);
  let bankerArtifact = await hre.artifacts.readArtifact("Banker");
  saveContractAbis(hre.network.name, 'Banker', bankerArtifact.abi, hre.network.name);

  // Deploy Treasury contract and set it to AddressManager
  const Treasury = await hre.ethers.getContractFactory("Treasury");
  const treasury = await upgrades.deployProxy(Treasury, [addressManager.address]);
  await treasury.deployed();
  await addressManager.setTreasuryContract(treasury.address);
  
  console.log("Treasury contract deployed to:", treasury.address);
  saveContractAddress(hre.network.name, 'Treasury', treasury.address);
  let treasuryArtifact = await hre.artifacts.readArtifact("Treasury");
  saveContractAbis(hre.network.name, 'Treasury', treasuryArtifact.abi, hre.network.name);

  // Deploy YearnUSDCStrategy contract and set it to AddressManager
  const YearnUSDCStrategy = await hre.ethers.getContractFactory("YearnUSDCStrategy");
  const yearnUSDCStrategy = await upgrades.deployProxy(YearnUSDCStrategy, [addressManager.address]);
  await yearnUSDCStrategy.deployed();
  await addressManager.setYearnUSDCStrategy(yearnUSDCStrategy.address);
  
  console.log("YearnUSDCStrategy contract deployed to:", yearnUSDCStrategy.address);
  saveContractAddress(hre.network.name, 'YearnUSDCStrategy', yearnUSDCStrategy.address);
  let yearnUSDCStrategyArtifact = await hre.artifacts.readArtifact("YearnUSDCStrategy");
  saveContractAbis(hre.network.name, 'YearnUSDCStrategy', yearnUSDCStrategyArtifact.abi, hre.network.name);

  // // Add strategy to Banker by manager
  // await banker.addStrategy("Treasury", "Ethereum", treasury.address, 0, 0, 0); // InsuranceAP = 0, DesiredAssetAP = 0%
  // await banker.addStrategy("Yearn Strategy", "Ethereum", yearnUSDCStrategy.address, 0, 10000, 0); // InsuranceAP = 0, DesiredAssetAP = 100%
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
