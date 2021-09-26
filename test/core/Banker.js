const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { expect } = chai;
const { ethers, upgrades } = require("hardhat");
const { parseUnits, parseEther } = require("@ethersproject/units");
const { swapETHForExactTokens } = require("../common/UniswapV2Router");
chai.use(solidity);

const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const yvUSDC_ADDRESS = "0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9";

const TEST_USDC_AMOUNT = parseUnits("10000", 6);

describe("Banker", function () {
  let usdcToken, banker, treasury, yearnUSDCStrategy, addressManager;

  before(async function () {
    [deployer, alice, manager, anchorMock] = await ethers.getSigners();

    // Deploy AddressManager
    const AddressManager = await ethers.getContractFactory("AddressManager");
    addressManager = await upgrades.deployProxy(AddressManager, [manager.address]);

    // Deploy Banker
    let mintDepositPercentage = 0;  // 100% MaxBanker
    let redemptionDelaytime = 60*60*24*7; // 7 days
    const Banker = await hre.ethers.getContractFactory("Banker");
    banker = await upgrades.deployProxy(Banker, [addressManager.address, mintDepositPercentage, redemptionDelaytime]);

    // Set Banker
    await addressManager.setBankerContract(banker.address);

    // Deploy Treasury
    const Treasury = await hre.ethers.getContractFactory("Treasury");
    treasury = await upgrades.deployProxy(Treasury, [addressManager.address]);
    
    // Deploy YearnUSDCStrategy
    YearnUSDCStrategy = await ethers.getContractFactory("YearnUSDCStrategy");
    yearnUSDCStrategy = await upgrades.deployProxy(YearnUSDCStrategy, [addressManager.address]);

    // Set Banker, Treasury and YearnUSDCStrategy
    await addressManager.setTreasuryContract(treasury.address);
    await addressManager.setYearnUSDCStrategy(yearnUSDCStrategy.address);

    // Add strategy to Banker
    await banker.connect(manager).addStrategy("Treasury", "Ethereum", treasury.address, 5000, 5000, 0); // InsuranceAP = 0, DesiredAssetAP = 0%
    await banker.connect(manager).addStrategy("Yearn Strategy", "Ethereum", yearnUSDCStrategy.address, 5000, 5000, 0); // InsuranceAP = 0, DesiredAssetAP = 100%

    // Get USDC
    usdcToken = await ethers.getContractAt("IERC20", USDC_ADDRESS, deployer);

    // Swap ETH for USDC and transfer to banker
    await swapETHForExactTokens(
      parseEther("10"),
      TEST_USDC_AMOUNT,
      USDC_ADDRESS,
      manager.address,
      deployer,
    );
  });

  describe("Initialize", function () {
    it("Should initialize the params", async function () {
      expect(await banker.mintDepositPercentage()).to.eq(0);
      expect((await banker.maxUSDInterestRate()).interestRate).to.eq(0);
      expect(await banker.redemptionDelayTime()).to.eq(60*60*24*7);
    });
  });

  describe("Turn on/off", function () {
    it("Should not turn off by non manager", async function () {
      await expect(banker.turnOff()).to.revertedWith("No manager");
    });

    it("Should turn off by manager", async function () {
      await banker.connect(manager).turnOff();
      expect(await banker.isTurnOff()).to.eq(true);
    });

    it("Should not turn off if already turned off", async function () {
      await expect(banker.connect(manager).turnOff()).to.revertedWith("Already turn off");
    });

    it("Should not turn on by non manager", async function () {
      await expect(banker.turnOn()).to.revertedWith("No manager");
    })

    it("Should turn on by manager", async function () {
      await banker.connect(manager).turnOn();
      expect(await banker.isTurnOff()).to.eq(false);
    });

    it("Should not turn on if already turned on", async function () {
      await expect(banker.connect(manager).turnOn()).to.revertedWith("Already turn on");
    });
  });

  describe("Strategy", function () {
    it("Should get all strategies", async function () {
      let strategies = await banker.getAllStrategies();
      
      expect(strategies.length).to.eq(2);
      expect(strategies[0]).to.eq(treasury.address);
      expect(strategies[1]).to.eq(yearnUSDCStrategy.address);
    });

    it("Should not add strategy by non manager", async function () {
      await expect(banker.addStrategy("Anchor", "ETH", anchorMock.address, 0, 0, 0)).to.be.revertedWith("No manager");
    });

    it("Should add strategy by manager", async function () {
      await banker.connect(manager).addStrategy("Anchor", "ETH", anchorMock.address, 0, 0, 0);
      let strategies = await banker.getAllStrategies();
      
      expect(strategies.length).to.eq(3);
      expect(strategies[0]).to.eq(treasury.address);
      expect(strategies[1]).to.eq(yearnUSDCStrategy.address);
      expect(strategies[2]).to.eq(anchorMock.address);
    });

    it("Should not remove strategy by non manager", async function () {
      await expect(banker.removeStrategy(anchorMock.address)).to.be.revertedWith("No manager");
    });

    it("Should remove strategy by manager", async function () {
      await banker.connect(manager).removeStrategy(anchorMock.address);
      let strategies = await banker.getAllStrategies();
      
      expect(strategies.length).to.eq(2);
      expect(strategies[0]).to.eq(treasury.address);
      expect(strategies[1]).to.eq(yearnUSDCStrategy.address);
    });

    it("Should set strategy insurance APs", async function () {
      let treasurySettings = await banker.strategySettings(treasury.address);
      let yearnSettings = await banker.strategySettings(yearnUSDCStrategy.address);

      expect(treasurySettings.insuranceAP).to.eq(5000);
      expect(yearnSettings.insuranceAP).to.eq(5000);

      await banker.connect(manager).setStrategyInsuranceAPs([treasury.address, yearnUSDCStrategy.address], [0, 10000]);

      treasurySettings = await banker.strategySettings(treasury.address);
      yearnSettings = await banker.strategySettings(yearnUSDCStrategy.address);

      expect(treasurySettings.insuranceAP).to.eq(0);
      expect(yearnSettings.insuranceAP).to.eq(10000);
    });

    it("Should set strategy desired APs", async function () {
      let treasurySettings = await banker.strategySettings(treasury.address);
      let yearnSettings = await banker.strategySettings(yearnUSDCStrategy.address);

      expect(treasurySettings.desiredAssetAP).to.eq(5000);
      expect(yearnSettings.desiredAssetAP).to.eq(5000);

      await banker.connect(manager).setStrategyDesiredAssetAPs([treasury.address, yearnUSDCStrategy.address], [0, 10000]);

      treasurySettings = await banker.strategySettings(treasury.address);
      yearnSettings = await banker.strategySettings(yearnUSDCStrategy.address);

      expect(treasurySettings.desiredAssetAP).to.eq(0);
      expect(yearnSettings.desiredAssetAP).to.eq(10000);
    });

    it("Should allocate asset", async function () {
      let treasuryAssetValue, yearnAssetValue, totalAssetValue;
      let firstDepositAmount, secondDepositAmount;

      // deposit: 1000, treasury: 0%, yearn: 100%
      firstDepositAmount = parseUnits("1000", 6);
      usdcToken.connect(manager).approve(treasury.address, firstDepositAmount);
      await treasury.connect(manager).buyDeposit(firstDepositAmount);

      await banker.connect(manager).allocate();

      treasuryAssetValue = await treasury.strategyAssetValue();
      yearnAssetValue = await yearnUSDCStrategy.strategyAssetValue();
      totalAsset = await banker.callStatic.getTotalAssetValue();

      expect(treasuryAssetValue).to.eq(0);
      expect(firstDepositAmount.sub(yearnAssetValue).lte(10)).to.eq(true);
      expect(firstDepositAmount.sub(totalAsset).lte(10)).to.eq(true);

      // deposit: 2000, treasury: 25%, yearn: 75%
      await banker.connect(manager).setStrategyDesiredAssetAPs([treasury.address, yearnUSDCStrategy.address], [2500, 7500]);

      secondDepositAmount = parseUnits("2000", 6);
      usdcToken.connect(manager).approve(treasury.address, secondDepositAmount);
      await treasury.connect(manager).buyDeposit(secondDepositAmount);

      await banker.connect(manager).allocate();

      treasuryAssetValue = await treasury.strategyAssetValue();
      yearnAssetValue = await yearnUSDCStrategy.strategyAssetValue();
      totalAsset = await banker.callStatic.getTotalAssetValue();

      expect(treasuryAssetValue.sub(totalAsset.mul(2500).div(10000)).lte(10)).to.eq(true);
      expect(yearnAssetValue.sub(totalAsset.mul(7500).div(10000)).lte(10)).to.eq(true);
      expect(totalAsset.sub(firstDepositAmount.add(secondDepositAmount)).lte(10)).to.eq(true);

      // no deposit, treasury: 50%, yearn: 50%
      await banker.connect(manager).setStrategyDesiredAssetAPs([treasury.address, yearnUSDCStrategy.address], [5000, 5000]);

      await banker.connect(manager).allocate();

      treasuryAssetValue = await treasury.strategyAssetValue();
      yearnAssetValue = await yearnUSDCStrategy.strategyAssetValue();
      totalAsset = await banker.callStatic.getTotalAssetValue();

      expect(treasuryAssetValue.sub(totalAsset.mul(5000).div(10000)).lte(10)).to.eq(true);
      expect(yearnAssetValue.sub(totalAsset.mul(5000).div(10000)).lte(10)).to.eq(true);
      expect(totalAsset.sub(firstDepositAmount.add(secondDepositAmount)).lte(10)).to.eq(true);
    });
  });
});
