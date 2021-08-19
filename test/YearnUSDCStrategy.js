const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ethers, upgrades } = require("hardhat");
const { parseUnits, parseEther } = require("@ethersproject/units");
const { swapETHForExactTokens } = require("./common/UniswapV2Router");
chai.use(solidity);

const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const yvUSDC_ADDRESS = "0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9";

const TEST_USDC_AMOUNT = parseUnits("1000", 6);

// Non-USDC Address for testing
const USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7";

describe("YearnUSDCStrategy", function () {
  let deployer;
  let usdcToken;
  let usdcStrategy;
  let YearnUSDCStrategy;
  let yvUSDCVault;

  before(async function () {
    [deployer] = await ethers.getSigners();

    usdcToken = await ethers.getContractAt("IERC20", USDC_ADDRESS, deployer);
    yvUSDCVault = await ethers.getContractAt("IYearnUSDCVault", yvUSDC_ADDRESS, deployer);
    YearnUSDCStrategy = await ethers.getContractFactory("YearnUSDCStrategy");
    usdcStrategy = await upgrades.deployProxy(YearnUSDCStrategy);
    await swapETHForExactTokens(parseEther("10"), parseUnits("10000", 6), USDC_ADDRESS, usdcStrategy.address, deployer);
  });

  describe("# initialize", function () {
    it("should be able to deploy as proxy", async function () {
      expect(await usdcStrategy.totalShares()).to.eq(0);
    });
  });

  describe("# invest", function () {
    it("should invest with above zero", async function () {
      await expect(usdcStrategy.invest(0)).to.revertedWith("amount should be above zero");
    });

    it("should invest with lower than limit", async function () {
      const availableDepositLimit = await yvUSDCVault.availableDepositLimit();
      await expect(usdcStrategy.invest(availableDepositLimit.add(1))).to.revertedWith(
        "amount should be lower than limit",
      );
    });

    it("should invest with lower than balance", async function () {
      await expect(usdcStrategy.invest(parseUnits("20000", 6))).to.revertedWith("amount should be lower than balance");
    });

    it("should be able to invest", async function () {
      const before = await usdcStrategy.totalShares();
      const pricePerShare = await yvUSDCVault.pricePerShare();
      // {6} is USDC decimals
      const estimation = TEST_USDC_AMOUNT.mul(10 ** 6).div(pricePerShare);
      await usdcStrategy.invest(TEST_USDC_AMOUNT);
      const after = await usdcStrategy.totalShares();
      // {10} is the max offset, while being invested.
      expect(estimation.sub(after.sub(before)).abs().lte(10)).to.eq(true);
    });
  });

  describe("# strategyAssetValue", function () {
    it("should be able to get storage asset value", async function () {
      const strategyAssetValue = await usdcStrategy.strategyAssetValue();
      const totalShares = await usdcStrategy.totalShares();
      const pricePerShare = await yvUSDCVault.pricePerShare();

      expect(strategyAssetValue).to.eq(
        totalShares
          .mul(pricePerShare)
          .mul(10 ** 2)
          .div(10 ** 6),
      );
    });
  });

  describe("# redeem", function () {
    it("should redeem with above zero", async function () {
      await expect(usdcStrategy.redeem(usdcStrategy.address, 0)).to.revertedWith("shares should be above zero");
    });

    it("should redeem with lower than total shares", async function () {
      const shares = await usdcStrategy.totalShares();
      const pricePerShare = await yvUSDCVault.pricePerShare();
      const exceedAmount = shares
        .mul(pricePerShare)
        .div(10 ** 6)
        .add(parseEther("10", 6));
      await expect(usdcStrategy.redeem(usdcStrategy.address, exceedAmount)).to.revertedWith(
        "shares should be lower than total shares",
      );
    });

    it("should be able to redeem", async function () {
      const shares = await usdcStrategy.totalShares();
      const pricePerShare = await yvUSDCVault.pricePerShare();
      const usdcAmount = shares.mul(pricePerShare).div(10 ** 6);

      const before = await usdcToken.balanceOf(usdcStrategy.address);
      usdcStrategy.redeem(usdcStrategy.address, usdcAmount);
      const after = await usdcToken.balanceOf(usdcStrategy.address);

      expect(TEST_USDC_AMOUNT.sub(after.sub(before)).lte(10)).to.eq(true);
    });
  });
});
