// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { getSavedContractAddresses, saveContractAddress, saveContractAbis } = require('./utils')

main = async () => {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // Deploy MaxBanker contract
  const MaxBanker = await hre.ethers.getContractFactory("MaxBanker");
  const maxBanker = await upgrades.deployProxy(MaxBanker, ["Maxos Mutual governance", "MAXOS"]);
  await maxBanker.deployed();

  console.log("MaxBanker contract deployed to:", maxBanker.address);
  saveContractAddress(hre.network.name, 'MaxBanker', maxBanker.address);
  let maxBankerArtifact = await hre.artifacts.readArtifact("MaxBanker");
  saveContractAbis(hre.network.name, 'MaxBanker', maxBankerArtifact.abi, hre.network.name);

  //----- Set OwnerOnlyApprover address -----//
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
