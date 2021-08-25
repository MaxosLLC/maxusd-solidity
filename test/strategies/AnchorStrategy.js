const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ethers, upgrades } = require("hardhat");
const { parseUnits, parseEther } = require("@ethersproject/units");
const { swapETHForExactTokens } = require("../common/UniswapV2Router");
chai.use(solidity);

const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const anchorUSDC_ADDRESS = "0x92E68C8C24a0267fa962470618d2ffd21f9b6a95";

const TEST_USDC_AMOUNT = parseUnits("1000", 6);

describe("AnchorStrategy", function () {
  let usdcToken, anchorStrategy, anchorUSDCVault, addressManager;

  before(async function () {
    [deployer, manager, banker] = await ethers.getSigners();

    // Deploy AddressManager
    const AddressManager = await ethers.getContractFactory("AddressManager");
    addressManager = await upgrades.deployProxy(AddressManager, [manager.address]);

    // Deploy AnchorStrategy
    AnchorStrategy = await ethers.getContractFactory("AnchorStrategy");
    anchorStrategy = await upgrades.deployProxy(AnchorStrategy, [addressManager.address]);

    // Set Banker, AnchorStrategy
    await addressManager.setBankerContract(banker.address);
    await addressManager.setAnchor(anchorStrategy.address);

    // Get IAnchorConversionPool and USDC
    anchorUSDCVault = await ethers.getContractAt("IAnchorConversionPool", anchorUSDC_ADDRESS, deployer);
    usdcToken = await ethers.getContractAt("IERC20", USDC_ADDRESS, deployer);

    // Swap ETH for USDC   
    await swapETHForExactTokens(parseEther("10"), parseUnits("10000", 6), USDC_ADDRESS, anchorStrategy.address, deployer);
  });
});
