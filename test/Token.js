const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const hre = require("hardhat");
const { expect } = require("chai");

describe("Token", () => {
  async function deployToken() {
    const Token = await hre.ethers.getContractFactory("Token");

    const [_, owner, supplier, ...accounts] = await hre.ethers.getSigners();
    const token = await Token.deploy(
      owner.address,
      1000,
      supplier.address,
      "Test token",
      "TTK",
      2
    );

    return { token, owner, supplier, accounts };
  }

  describe("when just deployed", () => {
    it("should be owned by deployer", async () => {
      const { token, owner } = await loadFixture(deployToken);

      expect(await token.owner()).to.equal(owner.address);
    });

    it("should send initial balance to supplier", async () => {
      const {
        token,
        supplier,
        accounts: [acc1],
      } = await loadFixture(deployToken);

      expect(await token.balanceOf(supplier.address)).to.equal(1000);
      expect(await token.balanceOf(acc1.address)).to.equal(0);
    });

    it("should have total supply equal to initial supply", async () => {
      const { token } = await loadFixture(deployToken);

      expect(await token.totalSupply()).to.equal(1000);
    });
  });

  describe("batchTransfer", () => {
    it("should transfer tokens to multiple accounts", async () => {
      const {
        token,
        supplier,
        accounts: [a1, a2, a3],
      } = await loadFixture(deployToken);

      await expect(
        token.connect(supplier).batchTransfer([a1, a2, a3], [10, 20, 42])
      ).to.changeTokenBalances(
        token,
        [supplier, a1, a2, a3],
        [-(10 + 20 + 42), 10, 20, 42]
      );
    });

    it("should revert when total amount is greater than balance", async () => {
      const {
        token,
        supplier,
        accounts: [a1, a2, a3],
      } = await loadFixture(deployToken);

      await expect(
        token.connect(supplier).batchTransfer([a1, a2, a3], [300, 400, 500])
      ).to.be.reverted;
    });
  });

  describe("issue", () => {
    it("should increase balance of specified address and increase total supply", async () => {
      const {
        token,
        owner,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await expect(token.connect(owner).issue(100, a1)).to.changeTokenBalance(token, a1, 100);
      expect(await token.totalSupply()).to.equal(1100);
    });

    it("should revert when called not by owner", async () => {
      const {
        token,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await expect(token.connect(a1).issue(100, a1)).to.be.reverted;
    });
  });
});
