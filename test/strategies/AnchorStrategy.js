const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ethers, upgrades } = require("hardhat");
const { parseUnits, parseEther } = require("@ethersproject/units");
const { swapETHForExactTokens } = require("../common/UniswapV2Router");
chai.use(solidity);

const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const AUSDC_ADDRESS = "0x94eAd8f528A3aF425de14cfdDA727B218915687C";
const UST_ADDRESS = '0xa47c8bf37f92abed4a126bda807a7b7498661acd';
const AUST_ADDRESS = '0xa8De3e3c934e2A1BB08B010104CcaBBD4D6293ab';
const anchorUSDC_ADDRESS = "0x53fD7e8fEc0ac80cf93aA872026EadF50cB925f3";
const exchangeRateFeeder_ADDRESS = "0xd7c4f5903De8A256a1f535AC71CeCe5750d5197a";

const TEST_USDC_AMOUNT = parseUnits("1000", 6);

describe("AnchorStrategy", function () {
  let usdcToken, aUsdcToken, ustToken, aUstToken, anchorStrategy, anchorUSDCVault, addressManager, exchangeRateFeeder;

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
    aUsdcToken = await ethers.getContractAt("IERC20", AUSDC_ADDRESS, deployer);
    ustToken = await ethers.getContractAt("IERC20", UST_ADDRESS, deployer);
    aUstToken = await ethers.getContractAt("IERC20", AUST_ADDRESS, deployer);
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
      console.log(TEST_USDC_AMOUNT + ' TEST_USDC_AMOUNT');
      const before = await anchorStrategy.totalShares();

      const usdcBefore = await usdcToken.balanceOf(anchorStrategy.address);
      var ustBefore = await ustToken.balanceOf(anchorStrategy.address);
      var aUstBefore = await aUstToken.balanceOf(anchorUSDCVault.address);
      var aUsdcBefore = await aUsdcToken.balanceOf(anchorStrategy.address);

      await anchorStrategy.connect(banker).invest(TEST_USDC_AMOUNT);

      var aUsdcAfter = await aUsdcToken.balanceOf(anchorStrategy.address);
      console.log(aUsdcBefore + ' aUsdc balance before');
      console.log(aUsdcAfter + ' aUsdc balance after');

      const usdcAfter = await usdcToken.balanceOf(anchorStrategy.address);
      console.log(usdcBefore + ' usdc balance before');
      console.log(usdcAfter + ' usdc balance after');

      const ustAfter = await ustToken.balanceOf(anchorStrategy.address);
      console.log(ustBefore + ' ust balance before');
      console.log(ustAfter + ' ust balance after');

      var aUstAfter = await aUstToken.balanceOf(anchorStrategy.address);
      console.log(aUstBefore + ' aUst balance before');
      console.log(aUstAfter + ' aUst balance after');

      const after = await anchorStrategy.totalShares();
      console.log(before + ' Anchor Strategy before');
      console.log(after + ' Anchor Strategy after');

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
        .div(10 ** 6)
        .add(parseEther("10", 6));
      await expect(anchorStrategy.connect(banker).redeem(anchorStrategy.address, exceedAmount)).to.revertedWith(
        "Invalid amount",
      );
    });

    it("Should redeem by banker", async function () {
      var aUsdcAmount = await aUsdcToken.balanceOf(anchorStrategy.address);
      console.log(aUsdcAmount + ' aUsdc balance before');

      await anchorStrategy.connect(banker).redeem(anchorStrategy.address, 100000000);
      
      var aUsdcAfter = await aUsdcToken.balanceOf(anchorStrategy.address);
      console.log(aUsdcAfter + ' aUsdc balance after');

      expect(aUsdcAmount.gt(aUsdcAfter));
    });
  });
});
