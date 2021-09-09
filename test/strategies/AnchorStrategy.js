const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ethers, upgrades } = require("hardhat");
const { parseUnits, parseEther } = require("@ethersproject/units");
const { swapETHForExactTokens } = require("../common/UniswapV2Router");
chai.use(solidity);

const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const anchorUSDC_ADDRESS = "0x53fD7e8fEc0ac80cf93aA872026EadF50cB925f3";
const exchangeRateFeeder_ADDRESS = "0xd7c4f5903De8A256a1f535AC71CeCe5750d5197a";

const TEST_USDC_AMOUNT = parseUnits("1000", 6);

describe("AnchorStrategy", function () {
  let usdcToken, anchorStrategy, anchorUSDCVault, addressManager, exchangeRateFeeder;

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
    exchangeRateFeeder = await ethers.getContractAt("IAnchorExchangeRateFeeder", exchangeRateFeeder_ADDRESS, deployer);

    // Swap ETH for USDC   
    await swapETHForExactTokens(parseEther("10"), parseUnits("10000", 6), USDC_ADDRESS, anchorStrategy.address, deployer);
  });

  describe("Initialize", function () {
    it("Should initialize total share", async function () {
      expect(await anchorStrategy.totalShares()).to.eq(0);
    });
  });

  describe("Invest", function () {
    it("Should not invest by non banker", async function () {
      await expect(anchorStrategy.invest(1)).to.revertedWith("No banker");
    });

    it("Should not invest with zero amount", async function () {
      await expect(anchorStrategy.connect(banker).invest(0)).to.revertedWith("Invalid amount");
    });

    it("Should not invest with the amount greater than than strategy balance", async function () {
      await expect(anchorStrategy.connect(banker).invest(parseUnits("20000", 6))).to.revertedWith("Invalid amount");
    });

    it("Should invest by banker", async function () {
      const before = await anchorStrategy.totalShares();

      await anchorStrategy.connect(banker).invest(TEST_USDC_AMOUNT);

      const after = await anchorStrategy.totalShares();

      expect(after.gt(before));
    });
  });

  describe("Redeem", function () {
    it("Should not redeem by non banker", async function () {
      await expect(anchorStrategy.redeem(anchorStrategy.address, 1)).to.revertedWith("No banker");
    });

    it("Should not redeem with zero amount", async function () {
      await expect(anchorStrategy.connect(banker).redeem(anchorStrategy.address, 0)).to.revertedWith("Invalid amount");
    });

    it("Should not redeem with the amount greater than total shares", async function () {
      const shares = await anchorStrategy.totalShares();
      var exchangeRate = await exchangeRateFeeder.exchangeRateOf(USDC_ADDRESS, false);

      const exceedAmount = shares
        .mul(exchangeRate)
        .div(10 ** 18)
        .add(parseEther("10", 6));
      await expect(anchorStrategy.connect(banker).redeem(anchorStrategy.address, exceedAmount)).to.revertedWith(
        "Invalid amount",
      );
    });

    it("Should redeem by banker", async function () {
      const shares = await anchorStrategy.totalShares();
      var exchangeRate = await exchangeRateFeeder.exchangeRateOf(USDC_ADDRESS, false);
      const usdcAmount = shares.mul(exchangeRate).div(10 ** 6);

      const before = await usdcToken.balanceOf(anchorStrategy.address);
      await anchorStrategy.connect(banker).redeem(anchorStrategy.address, usdcAmount);
      const after = await usdcToken.balanceOf(anchorStrategy.address);

      expect(TEST_USDC_AMOUNT.sub(after.sub(before)).lte(10)).to.eq(true);
    });
  });

  describe("Anchor Contracts", function () {
    it("Deposit", async function () {
      await anchorUSDCVault.connect(banker).deposit(parseUnits("20000", 6));
    });

    it("Redeem", async function () {
      await anchorUSDCVault.connect(banker).redeem(parseUnits("20000", 6))
    });

    it("Exchange Rate", async function () {
      var exchangeRate = await exchangeRateFeeder.exchangeRateOf(USDC_ADDRESS, false);
      console.log("Exchange rate", exchangeRate);
    });
  });
});
