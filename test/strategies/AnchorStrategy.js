const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ethers, upgrades } = require("hardhat");
const { parseUnits, parseEther } = require("@ethersproject/units");
const { swapETHForExactTokens } = require("../common/UniswapV2Router");
chai.use(solidity);

const USDC_ADDRESS = "0xE015FD30cCe08Bc10344D934bdb2292B1eC4BBBD";
const anchorUSDC_ADDRESS = "0x92E68C8C24a0267fa962470618d2ffd21f9b6a95";
const exchangeRateFeeder_ADDRESS = "0x79E0d9bD65196Ead00EE75aB78733B8489E8C1fA";

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
    //await swapETHForExactTokens(parseEther("10"), parseUnits("10000", 6), USDC_ADDRESS, anchorStrategy.address, deployer);
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
        .div(10 ** 6)
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

    it("Should not redeem with the amount greater than total shares", async function () {
      const shares = await anchorStrategy.totalShares();
      var exchangeRate = await exchangeRateFeeder.exchangeRateOf(USDC_ADDRESS, false);
      const exceedAmount = shares
        .mul(exchangeRate)
        .div(10 ** 18)
        .add(parseEther("10", 6));
      await expect(yearnUSDCStrategy.connect(banker).redeem(yearnUSDCStrategy.address, exceedAmount)).to.revertedWith(
        "Invalid amount",
      );
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
