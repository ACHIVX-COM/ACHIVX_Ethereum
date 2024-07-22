const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const hre = require("hardhat");
const { expect } = require("chai");

describe("Token upgrade", () => {
  async function deployTokenAndUpgrade() {
    const Token = await hre.ethers.getContractFactory("Token");
    const TestTokenUpgrade = await hre.ethers.getContractFactory(
      "TestTokenUpgrade"
    );

    const [_, owner, supplier, ...accounts] = await hre.ethers.getSigners();

    const token = await Token.deploy(
      owner.address,
      1000,
      supplier.address,
      "Test token",
      "TTK",
      2
    );
    const upgrade = await TestTokenUpgrade.deploy(token);

    return { owner, supplier, accounts, token, upgrade };
  }

  async function deployTokenAndUpgradeAndDeprecateToken() {
    const { owner, token, upgrade, supplier, accounts, ...rest } =
      await loadFixture(deployTokenAndUpgrade);

    await token.connect(supplier).transfer(accounts[0], 100);
    await token.connect(supplier).transfer(accounts[1], 200);

    await token.connect(owner).deprecate(upgrade);

    return { owner, token, upgrade, supplier, accounts, ...rest };
  }

  describe("when token is not yet deprecated", () => {
    it("should not allow any method calls", async () => {
      const {
        upgrade,
        supplier,
        accounts: [a1],
      } = await loadFixture(deployTokenAndUpgrade);

      await expect(
        upgrade.connect(supplier).transfer(a1, 100)
      ).to.be.revertedWith("contract not deprecated");
      await expect(upgrade.balanceOf(a1)).to.be.revertedWith(
        "contract not deprecated"
      );
      await expect(upgrade.transferFrom(supplier, a1, 100)).to.be.revertedWith(
        "contract not deprecated"
      );
    });

    it("should have total supply of legacy token", async () => {
      const { upgrade } = await loadFixture(deployTokenAndUpgrade);

      expect(await upgrade.totalSupply()).to.be.equal(1000);
    });

    it("token should be upgradeable with upgrade contract", async () => {
      const { token, owner, upgrade } = await loadFixture(
        deployTokenAndUpgrade
      );

      await expect(token.connect(owner).deprecate(upgrade)).not.to.be.reverted;
    });
  });

  describe("when token is deprecated", () => {
    it("should inherit balances from legacy contract", async () => {
      const { upgrade, supplier, accounts } = await loadFixture(
        deployTokenAndUpgradeAndDeprecateToken
      );

      expect(await upgrade.balanceOf(supplier)).to.be.equal(700);
      expect(await upgrade.balanceOf(accounts[0])).to.be.equal(100);
      expect(await upgrade.balanceOf(accounts[1])).to.be.equal(200);
    });

    it("should allow transfers and reflect transfers to legacy tokens", async () => {
      const { token, upgrade, supplier, accounts } = await loadFixture(
        deployTokenAndUpgradeAndDeprecateToken
      );

      const tx = upgrade.connect(supplier).transfer(accounts[2], 300);
      await expect(tx).to.changeTokenBalances(
        upgrade,
        [supplier, accounts[2]],
        [-300, 300]
      );
      await expect(tx).to.changeTokenBalances(
        token,
        [supplier, accounts[2]],
        [-300, 300]
      );
      await expect(tx).to.emit(token, 'Transfer').withArgs(supplier, accounts[2], 300);
      await expect(tx).to.emit(upgrade, 'Transfer').withArgs(supplier, accounts[2], 300);
    });

    it("should execute transfers poxed from legacy contract", async () => {
      const { token, upgrade, supplier, accounts } = await loadFixture(
        deployTokenAndUpgradeAndDeprecateToken
      );

      const tx = token.connect(supplier).transfer(accounts[2], 300);
      await expect(tx).to.changeTokenBalances(
        upgrade,
        [supplier, accounts[2]],
        [-300, 300]
      );
      await expect(tx).to.changeTokenBalances(
        token,
        [supplier, accounts[2]],
        [-300, 300]
      );
      await expect(tx).to.emit(token, 'Transfer').withArgs(supplier, accounts[2], 300);
      await expect(tx).to.emit(upgrade, 'Transfer').withArgs(supplier, accounts[2], 300);
    })
  });
});
