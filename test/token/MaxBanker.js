const { expect } = require("chai");
const { upgrades } = require("hardhat");
const { constants } = require("ethers");

describe("MaxBanker", () => {
  let maxBanker, ownerOnlyApprover;

  const MINT_AMOUNT = 100;
  const BURN_AMOUNT = 50;

  beforeEach(async () => {
    [deployer, owner, mintContract, alice, bob] = await ethers.getSigners();

    const MaxBanker = await ethers.getContractFactory("MaxBanker");
    maxBanker = await upgrades.deployProxy(MaxBanker, ["Maxos Mutual governance", "MAXOS"]);

    const OwnerOnlyApprover = await ethers.getContractFactory("OwnerOnlyApprover");
    ownerOnlyApprover = await upgrades.deployProxy(OwnerOnlyApprover);
  });

  describe("Token", async () => {
    it("Should have correct name/symbol", async () => {
      expect(await maxBanker.name()).to.be.equal("Maxos Mutual governance");
      expect(await maxBanker.symbol()).to.be.equal("MAXOS");
    });
  });

  describe("Ownership", (async) => {
    it("Should not transfer ownership by non owner", async () => {
      expect(await maxBanker.owner()).to.equal(deployer.address);
      await expect(maxBanker.connect(alice).transferOwnership(owner.address)).to.be.reverted;
    });

    it("Should transfer ownership by owner", async () => {
      expect(await maxBanker.owner()).to.equal(deployer.address);
      await maxBanker.connect(deployer).transferOwnership(owner.address);
      expect(await maxBanker.owner()).to.equal(owner.address);
    });
  });

  describe("Pause/Unpause token", async () => {
    it("Should not pause by non owner", async () => {
      await expect(maxBanker.connect(alice).pause()).reverted;
    });

    it("Should not pause by non owner", async () => {
      expect(await maxBanker.paused()).to.be.false;

      await maxBanker.connect(deployer).transferOwnership(owner.address);
      await expect(maxBanker.connect(deployer).pause()).reverted;
      await maxBanker.connect(owner).pause();
      expect(await maxBanker.paused()).to.be.true;
    });

    it("Should not unpause by non owner", async () => {
      await maxBanker.connect(deployer).transferOwnership(owner.address);
      await maxBanker.connect(owner).pause();
      expect(await maxBanker.paused()).to.be.true;

      await expect(maxBanker.connect(deployer).unpause()).reverted;
    });

    it("Should not pause by non owner", async () => {
      await maxBanker.connect(deployer).transferOwnership(owner.address);
      await maxBanker.connect(owner).pause();
      expect(await maxBanker.paused()).to.be.true;

      await maxBanker.connect(owner).unpause();
      expect(await maxBanker.paused()).to.be.false;
    });

    it("Should not pause when paused", async () => {
      await maxBanker.pause();
      await expect(maxBanker.pause()).revertedWith("Pausable: paused");
    });

    it("Should not unpause when unpaused", async () => {
      await maxBanker.pause();
      await maxBanker.unpause();
      await expect(maxBanker.unpause()).revertedWith("Pausable: not paused");
    });
  });

  describe("Mint/Burn tokens", async () => {
    it("Should not mint token by non minter", async () => {
      expect(await maxBanker.balanceOf(alice.address)).to.equal(0);
      await expect(maxBanker.connect(alice).mint(alice.address, MINT_AMOUNT)).to.be.revertedWith("No minter");
    });

    it("Should mint token by minter", async () => {
      await maxBanker.pause();
      await expect(maxBanker.mint(alice.address, MINT_AMOUNT)).to.revertedWith("Pausable: paused");

      await maxBanker.unpause();
      expect(await maxBanker.balanceOf(alice.address)).to.equal(0);
      await maxBanker.mint(alice.address, MINT_AMOUNT);
      expect(await maxBanker.balanceOf(alice.address)).to.equal(MINT_AMOUNT);
    });

    it("Should burn his token by burner himself", async () => {
      await maxBanker.mint(deployer.address, MINT_AMOUNT);
      await maxBanker.pause();
      await expect(maxBanker.burn(BURN_AMOUNT)).to.revertedWith("Pausable: paused");

      await maxBanker.unpause();
      await maxBanker.burn(BURN_AMOUNT);
      let restAmount = MINT_AMOUNT - BURN_AMOUNT;
      expect(await maxBanker.balanceOf(deployer.address)).to.equal(restAmount);
    });

    it("Should not mint token by non mintContract", async () => {
      await expect(maxBanker.connect(mintContract).mint(alice.address, MINT_AMOUNT)).to.be.revertedWith("No minter");
    });

    it("Should mint token by mintContract", async () => {
      expect(await maxBanker.balanceOf(alice.address)).to.equal(0);
      await maxBanker.setMintContract(mintContract.address);
      await maxBanker.connect(mintContract).mint(alice.address, MINT_AMOUNT);
      expect(await maxBanker.balanceOf(alice.address)).to.equal(MINT_AMOUNT);
    });
  });

  describe("Token Transfer", async () => {
    it("Should not set ownerOnlyApprover address by non owner", async () => {
      await expect(maxBanker.connect(alice).setOwnerOnlyApprover(ownerOnlyApprover.address)).reverted;
    });

    it("Should set ownerOnlyApprover address by non owner", async () => {
      expect(await maxBanker.ownerOnlyApprover()).to.be.equal(constants.AddressZero);
      await maxBanker.connect(deployer).transferOwnership(owner.address);

      await maxBanker.connect(owner).setOwnerOnlyApprover(ownerOnlyApprover.address);
      expect(await maxBanker.ownerOnlyApprover()).to.be.equal(ownerOnlyApprover.address);
    });

    it("Should not tranasfer between normal users", async () => {
      await expect(maxBanker.connect(owner).setOwnerOnlyApprover(ownerOnlyApprover.address)).to.reverted;
      await maxBanker.transferOwnership(owner.address);
      await maxBanker.connect(owner).setOwnerOnlyApprover(ownerOnlyApprover.address);
      expect(await maxBanker.ownerOnlyApprover()).to.be.equal(ownerOnlyApprover.address);

      // users
      await maxBanker.connect(owner).mint(alice.address, MINT_AMOUNT);
      await maxBanker.connect(owner).mint(bob.address, MINT_AMOUNT);
      await expect(maxBanker.connect(alice).transfer(bob.address, MINT_AMOUNT)).to.be.reverted;

      // mintContract
      await maxBanker.connect(owner).setMintContract(mintContract.address);
      await maxBanker.connect(owner).mint(mintContract.address, MINT_AMOUNT);
      await expect(maxBanker.connect(alice).transfer(mintContract.address, MINT_AMOUNT)).to.be.reverted;
      await expect(maxBanker.connect(mintContract).transfer(alice.address, MINT_AMOUNT)).to.be.reverted;
    });

    it("Should tranasfer by owner", async () => {
      await maxBanker.transferOwnership(owner.address);
      await maxBanker.connect(owner).setOwnerOnlyApprover(ownerOnlyApprover.address);

      // mint
      await maxBanker.connect(owner).mint(alice.address, MINT_AMOUNT);
      expect(await maxBanker.balanceOf(alice.address)).to.equal(MINT_AMOUNT);

      // pause
      await maxBanker.connect(owner).pause();
      await expect(maxBanker.connect(alice).transfer(owner.address, MINT_AMOUNT)).to.revertedWith("Pausable: paused");
      await maxBanker.connect(alice).approve(owner.address, 1);
      await expect(maxBanker.connect(owner).transferFrom(alice.address, bob.address, 1)).to.revertedWith(
        "Pausable: paused",
      );

      // unpause
      await maxBanker.connect(owner).unpause();

      // transfer
      await maxBanker.connect(alice).transfer(owner.address, MINT_AMOUNT);
      expect(await maxBanker.balanceOf(owner.address)).to.equal(MINT_AMOUNT);
      await maxBanker.connect(owner).transfer(alice.address, MINT_AMOUNT);
      expect(await maxBanker.balanceOf(alice.address)).to.equal(MINT_AMOUNT);

      // transferFrom
      await maxBanker.connect(alice).approve(owner.address, 1);
      let aliceBalanceBefore = await maxBanker.balanceOf(alice.address);
      let ownerBalanceBefore = await maxBanker.balanceOf(owner.address);
      await maxBanker.connect(owner).transferFrom(alice.address, owner.address, 1);
      expect(await maxBanker.balanceOf(alice.address)).to.equal(aliceBalanceBefore.sub(1));
      expect(await maxBanker.balanceOf(owner.address)).to.equal(ownerBalanceBefore.add(1));

      await maxBanker.connect(owner).transfer(alice.address, 1);

      // burn
      await maxBanker.connect(alice).burn(MINT_AMOUNT);
      expect(await maxBanker.balanceOf(alice.address)).to.equal(0);
    });
  });
});
