const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ethers, upgrades } = require("hardhat");
const { parseUnits, parseEther } = require("@ethersproject/units");
const { swapETHForExactTokens } = require("../common/UniswapV2Router");
chai.use(solidity);

const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const yvUSDC_ADDRESS = "0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9";

const TEST_USDC_AMOUNT = parseUnits("1000", 6);

describe("YearnUSDCStrategy", function () {
  let usdcToken, yearnUSDCStrategy, yvUSDCVault, addressManager;

  before(async function () {
    [deployer, manager, banker] = await ethers.getSigners();

    // Deploy AddressManager
    const AddressManager = await ethers.getContractFactory("AddressManager");
    addressManager = await upgrades.deployProxy(AddressManager, [manager.address]);

    // Deploy YearnUSDCStrategy
    YearnUSDCStrategy = await ethers.getContractFactory("YearnUSDCStrategy");
    yearnUSDCStrategy = await upgrades.deployProxy(YearnUSDCStrategy, [addressManager.address]);

    // Set Banker, YearnUSDCStrategy
    await addressManager.setBankerContract(banker.address);
    await addressManager.setYearnUSDCStrategy(yearnUSDCStrategy.address);

    // Get yvUSDCVault and USDC
    yvUSDCVault = await ethers.getContractAt("IYearnUSDCVault", yvUSDC_ADDRESS, deployer);
    usdcToken = await ethers.getContractAt("IERC20", USDC_ADDRESS, deployer);

    // Swap ETH for USC
    await swapETHForExactTokens(
      parseEther("10"),
      parseUnits("10000", 6),
      USDC_ADDRESS,
      yearnUSDCStrategy.address,
      deployer,
    );
  });

  describe("Initialize", function () {
    it("Should initialize total share", async function () {
      expect(await yearnUSDCStrategy.totalShares()).to.eq(0);
    });
  });

  describe("Invest", function () {
    it("Should not invest by non banker", async function () {
      await expect(yearnUSDCStrategy.invest(1)).to.revertedWith("No banker");
    });

    it("Should not invest with zero amount", async function () {
      await expect(yearnUSDCStrategy.connect(banker).invest(0)).to.revertedWith("Invalid amount");
    });

    it("Should not invest with the amount greater than limit", async function () {
      const availableDepositLimit = await yvUSDCVault.availableDepositLimit();
      await expect(yearnUSDCStrategy.connect(banker).invest(availableDepositLimit.add(1))).to.revertedWith(
        "Limit overflow",
      );
    });

    it("Should not invest with the amount greater than than strategy balance", async function () {
      await expect(yearnUSDCStrategy.connect(banker).invest(parseUnits("20000", 6))).to.revertedWith("Invalid amount");
    });

    it("Should invest by banker", async function () {
      const before = await yearnUSDCStrategy.totalShares();
      const pricePerShare = await yvUSDCVault.pricePerShare();
      // {6} is USDC decimals
      const estimation = TEST_USDC_AMOUNT.mul(10 ** 6).div(pricePerShare);
      await yearnUSDCStrategy.connect(banker).invest(TEST_USDC_AMOUNT);
      const after = await yearnUSDCStrategy.totalShares();
      // {10} is the max offset, while being invested.

      expect(estimation.sub(after.sub(before)).abs().lte(10)).to.eq(true);
    });
  });

  describe("StrategyAssetValue", function () {
    it("Should get the asset value", async function () {
      const strategyAssetValue = await yearnUSDCStrategy.strategyAssetValue();
      const totalShares = await yearnUSDCStrategy.totalShares();
      const pricePerShare = await yvUSDCVault.pricePerShare();

      expect(strategyAssetValue).to.eq(
        totalShares
          .mul(pricePerShare)
          .mul(10 ** 2)
          .div(10 ** 6),
      );
    });
  });

  describe("Redeem", function () {
    it("Should not redeem by non banker", async function () {
      await expect(yearnUSDCStrategy.redeem(yearnUSDCStrategy.address, 1)).to.revertedWith("No banker");
    });

    it("Should not redeem with zero amount", async function () {
      await expect(yearnUSDCStrategy.connect(banker).redeem(yearnUSDCStrategy.address, 0)).to.revertedWith(
        "Invalid amount",
      );
    });

    it("Should not redeem with the amount greater than total shares", async function () {
      const shares = await yearnUSDCStrategy.totalShares();
      const pricePerShare = await yvUSDCVault.pricePerShare();
      const exceedAmount = shares
        .mul(pricePerShare)
        .div(10 ** 6)
        .add(parseEther("10", 6));
      await expect(yearnUSDCStrategy.connect(banker).redeem(yearnUSDCStrategy.address, exceedAmount)).to.revertedWith(
        "Invalid amount",
      );
    });

    it("Should redeem by banker", async function () {
      const shares = await yearnUSDCStrategy.totalShares();
      const pricePerShare = await yvUSDCVault.pricePerShare();
      const usdcAmount = shares.mul(pricePerShare).div(10 ** 6);

      const before = await usdcToken.balanceOf(yearnUSDCStrategy.address);
      await yearnUSDCStrategy.connect(banker).redeem(yearnUSDCStrategy.address, usdcAmount);
      const after = await usdcToken.balanceOf(yearnUSDCStrategy.address);

      expect(TEST_USDC_AMOUNT.sub(after.sub(before)).lte(10)).to.eq(true);
    });
  });
});
