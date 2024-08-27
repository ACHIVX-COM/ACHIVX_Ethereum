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
    it("should be owned by the owner", async () => {
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

  describe("transfer", () => {
    it("should transfer tokens", async () => {
      const {
        token,
        supplier,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await expect(
        token.connect(supplier).transfer(a1, 100)
      ).to.changeTokenBalances(token, [supplier, a1], [-100, 100]);
    });

    it("should emit transfer events", async () => {
      const {
        token,
        supplier,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await expect(token.connect(supplier).transfer(a1, 100))
        .to.emit(token, "Transfer")
        .withArgs(supplier, a1, 100);
    });

    it("should revert when transferring amount beyond current balance", async () => {
      const {
        token,
        supplier,
        accounts: [a1, a2],
      } = await loadFixture(deployToken);

      await expect(token.connect(supplier).transfer(a1, 1001)).to.be.reverted;

      await expect(token.connect(a1).transfer(a2, 1)).to.be.reverted;
    });
  });

  describe("approve", () => {
    it("should change allowance", async () => {
      const {
        token,
        supplier,
        accounts: [a1],
      } = await loadFixture(deployToken);

      expect(await token.allowance(supplier, a1)).to.be.equal(0);
      await token.connect(supplier).approve(a1, 100);
      expect(await token.allowance(supplier, a1)).to.be.equal(100);
    });

    it("should emit approval events", async () => {
      const {
        token,
        supplier,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await expect(token.connect(supplier).approve(a1, 100))
        .to.emit(token, "Approval")
        .withArgs(supplier, a1, 100);
    });

    it("should not allow changing allowance from non-zero value to non-zero value", async () => {
      const {
        token,
        supplier,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await token.connect(supplier).approve(a1, 100);
      await expect(token.connect(supplier).approve(a1, 200)).to.be.reverted;
    });

    it("should allow changing allowance from non-zero to zero and back", async () => {
      const {
        token,
        supplier,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await token.connect(supplier).approve(a1, 100);
      await token.connect(supplier).approve(a1, 0);
      await token.connect(supplier).approve(a1, 200);
    });
  });

  describe("transferFrom", () => {
    it("should transfer tokens", async () => {
      const {
        token,
        supplier,
        accounts: [a1, a2],
      } = await loadFixture(deployToken);

      await token.connect(supplier).approve(a1, 100);
      await expect(
        token.connect(a1).transferFrom(supplier, a2, 100)
      ).to.changeTokenBalances(token, [supplier, a2], [-100, 100]);
    });

    it("should revert when trying to transfer tokens beyond allowance", async () => {
      const {
        token,
        supplier,
        accounts: [a1, a2],
      } = await loadFixture(deployToken);

      await token.connect(supplier).approve(a1, 100);
      await expect(
        token.connect(a1).transferFrom(supplier, a2, 101)
      ).to.be.reverted;
    });

    it("should revert when trying to transfer tokens within allowance but beyond owner's balance", async () => {
      const {
        token,
        supplier,
        accounts: [a1, a2],
      } = await loadFixture(deployToken);

      await token.connect(supplier).approve(a1, 100000);
      await expect(
        token.connect(a1).transferFrom(supplier, a2, 1001)
      ).to.be.reverted;
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

      await expect(token.connect(owner).issue(100, a1)).to.changeTokenBalance(
        token,
        a1,
        100
      );
      expect(await token.totalSupply()).to.equal(1100);
    });

    it("should revert when called not by owner", async () => {
      const {
        token,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await expect(token.connect(a1).issue(100, a1)).to.be.reverted;
    });

    it("should revert on overflow", async () => {
      const {
        token,
        owner,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await token
        .connect(owner)
        .issue(
          "0x8000000000000000000000000000000000000000000000000000000000000000",
          a1
        );
      await expect(
        token
          .connect(owner)
          .issue(
            "0x8000000000000000000000000000000000000000000000000000000000000000",
            a1
          )
      ).to.be.reverted;
    });
  });

  describe("redeem", () => {
    it("should not be callable by non-owner", async () => {
      const { token } = await loadFixture(deployToken);

      await expect(token.redeem(100)).to.be.revertedWith("not an owner");
    });

    it("should revert when owner balance is too low", async () => {
      const { token, owner, supplier } = await loadFixture(deployToken);

      await token.connect(supplier).transfer(owner, 100);
      await expect(token.connect(owner).redeem(150)).to.be.reverted;
    });

    it("should destroy funds from owner account", async () => {
      const { token, owner, supplier } = await loadFixture(deployToken);

      await token.connect(supplier).transfer(owner, 100);
      await expect(token.connect(owner).redeem(50)).to.changeTokenBalance(
        token,
        owner,
        -50
      );
      expect(await token.totalSupply()).to.be.equal(950);
    });
  });

  describe("pause+unpause", () => {
    it("should not be callable by non-owner", async () => {
      const { token } = await loadFixture(deployToken);

      await expect(token.pause()).to.be.revertedWith("not an owner");
      await expect(token.unpause()).to.be.revertedWith("not an owner");
    });

    it("should pause any transfer operations", async () => {
      const {
        token,
        owner,
        accounts: [a1, a2],
      } = await loadFixture(deployToken);

      await token.connect(owner).pause();
      expect(await token.paused()).to.be.true;

      await expect(token.transfer(a1, 100)).to.be.revertedWith(
        "contract paused"
      );
      await expect(token.transferFrom(a1, a2, 100)).to.be.revertedWith(
        "contract paused"
      );
      await expect(
        token.batchTransfer([a1, a2], [100, 200])
      ).to.be.revertedWith("contract paused");

      await token.connect(owner).unpause();
      expect(await token.paused()).to.be.false;
    });
  });

  describe("addBlackList+removeBlackList", () => {
    it("should not be callable by non-owner", async () => {
      const {
        token,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await expect(token.addBlackList(a1)).to.be.revertedWith("not an owner");
      await expect(token.removeBlackList(a1)).to.be.revertedWith(
        "not an owner"
      );
    });

    it("should pause operation for blacklisted account", async () => {
      const {
        token,
        owner,
        accounts: [a1, a2],
      } = await loadFixture(deployToken);

      expect(await token.isBlackListed(a1)).to.be.false;
      await token.connect(owner).addBlackList(a1);
      expect(await token.isBlackListed(a1)).to.be.true;

      await expect(token.connect(a1).transfer(a2, 100)).to.be.revertedWith(
        "account blacklisted"
      );
      await expect(
        token.connect(a1).batchTransfer([a2], [100])
      ).to.be.revertedWith("account blacklisted");
      await expect(
        token.connect(a2).transferFrom(a1, a2, 100)
      ).to.be.revertedWith("account blacklisted");

      await token.connect(owner).removeBlackList(a1);
      expect(await token.isBlackListed(a1)).to.be.false;
    });
  });

  describe("destroyBlackFunds", () => {
    it("should not be callable by non-owner", async () => {
      const {
        token,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await expect(token.destroyBlackFunds(a1)).to.be.revertedWith(
        "not an owner"
      );
    });

    it("should not work for non-blacklisted accounts", async () => {
      const {
        token,
        owner,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await expect(
        token.connect(owner).destroyBlackFunds(a1)
      ).to.be.revertedWith("account not blacklisted");
    });

    it("should destroy funds of blacklisted account", async () => {
      const {
        token,
        owner,
        supplier,
        accounts: [a1],
      } = await loadFixture(deployToken);

      await token.connect(supplier).transfer(a1, 100);
      await token.connect(owner).addBlackList(a1);

      await expect(
        token.connect(owner).destroyBlackFunds(a1)
      ).to.changeTokenBalance(token, a1, -100);
      expect(await token.totalSupply()).to.be.equal(900);
    });
  });

  describe("supportsInterface", () => {
    it("should support ERC165", async () => {
      const { token } = await loadFixture(deployToken);

      // Standard procedure to check for ERC165 support (https://eips.ethereum.org/EIPS/eip-165)
      expect(await token.supportsInterface("0x01ffc9a7")).to.be.true;
      expect(await token.supportsInterface("0xffffffff")).to.be.false;
    });

    it("should support ERC20 and ERC173", async () => {
      const { token } = await loadFixture(deployToken);

      expect(await token.supportsInterface("0x7f5828d0")).to.be.true;
      expect(await token.supportsInterface("0x36372b07")).to.be.true;
    });
  });
});
