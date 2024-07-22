const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const hre = require("hardhat");
const { expect } = require("chai");

describe("Token with MultisigManager", () => {
  async function deployTokenWithMultisigManager() {
    const Token = await hre.ethers.getContractFactory("Token");
    const MultisigManager = await hre.ethers.getContractFactory(
      "MultisigManager"
    );

    const [_, supplier, voter1, voter2, voter3, ...accounts] =
      await hre.ethers.getSigners();
    const voters = [voter1, voter2, voter3];

    const multisigManager = await MultisigManager.deploy(voters);
    const token = await Token.deploy(
      multisigManager,
      1000,
      supplier.address,
      "Test token",
      "TTK",
      2
    );

    return { supplier, voters, accounts, token, multisigManager };
  }

  /**
   * @param {import('ethers').Contract} contract
   * @param {string} eventName
   * @returns {Promise<string>}
   */
  async function getLastRequestId(contract, eventName) {
    const [event] = await contract.queryFilter(contract.getEvent(eventName));
    const reqId = event.args.reqId;
    expect(reqId).to.not.be.undefined;
    return reqId;
  }

  describe("getMinApprovals", () => {
    it("should return 2 when there are 3 voting accounts", async () => {
      const { multisigManager } = await loadFixture(
        deployTokenWithMultisigManager
      );

      expect(await multisigManager.getMinApprovals()).to.equal(2);
    });

    it("should return 3 when fourth voter is added", async () => {
      const {
        multisigManager,
        voters,
        accounts: [a1],
      } = await loadFixture(deployTokenWithMultisigManager);

      await (
        await multisigManager
          .connect(voters[0])
          .requestVotersListChange([a1], [])
      ).wait();
      await (
        await multisigManager
          .connect(voters[1])
          .approveVotersListChange(
            await getLastRequestId(multisigManager, "VotersListChangeRequested")
          )
      ).wait();

      expect(await multisigManager.getMinApprovals()).to.equal(3);
    });
  });

  describe("requestIssue+approveIssue", async () => {
    it("should increase total supply and add funds to specified address when necessary number of voters agree", async () => {
      const {
        multisigManager,
        token,
        voters,
        accounts: [a1],
      } = await loadFixture(deployTokenWithMultisigManager);

      await multisigManager.connect(voters[1]).requestIssue(token, 100, a1);
      await expect(
        multisigManager
          .connect(voters[2])
          .approveIssue(
            await getLastRequestId(multisigManager, "IssueRequested")
          )
      ).to.changeTokenBalance(token, a1, 100);
      expect(await token.balanceOf(a1)).to.equal(100);
    });

    it("should not accept approvals after request execution", async () => {
      const {
        multisigManager,
        token,
        voters,
        accounts: [a1],
      } = await loadFixture(deployTokenWithMultisigManager);

      await multisigManager.connect(voters[1]).requestIssue(token, 100, a1);
      await multisigManager
        .connect(voters[2])
        .approveIssue(
          await getLastRequestId(multisigManager, "IssueRequested")
        );
      await expect(
        multisigManager
          .connect(voters[0])
          .approveIssue(
            await getLastRequestId(multisigManager, "IssueRequested")
          )
      ).to.be.revertedWith("request already completed");
    });

    it("should not allow double approval", async () => {
      const {
        multisigManager,
        token,
        voters,
        accounts: [a1],
      } = await loadFixture(deployTokenWithMultisigManager);

      await multisigManager.connect(voters[2]).requestIssue(token, 100, a1);
      await expect(
        multisigManager
          .connect(voters[2])
          .approveIssue(
            await getLastRequestId(multisigManager, "IssueRequested")
          )
      ).to.be.rejectedWith("already approved by this account");
    });

    it("should not receive requests from non-voting addresses", async () => {
      const {
        multisigManager,
        token,
        accounts: [a1, a2],
      } = await loadFixture(deployTokenWithMultisigManager);

      await expect(
        multisigManager.connect(a1).requestIssue(token, 100, a2)
      ).to.be.rejectedWith("not a voting account");
    });

    it("should not receive votes from non-voting accounts", async () => {
      const {
        multisigManager,
        token,
        voters,
        accounts: [a1, a2],
      } = await loadFixture(deployTokenWithMultisigManager);

      await multisigManager.connect(voters[1]).requestIssue(token, 100, a2);
      await expect(
        multisigManager
          .connect(a1)
          .approveIssue(
            await getLastRequestId(multisigManager, "IssueRequested")
          )
      ).to.be.rejectedWith("not a voting account");
    });
  });

  describe("requestRedeem+approveRedeem", () => {
    it("should redeem tokens from owner account", async () => {
      const { multisigManager, token, voters, supplier } = await loadFixture(
        deployTokenWithMultisigManager
      );

      await token.connect(supplier).transfer(multisigManager, 100);

      await multisigManager.connect(voters[0]).requestRedeem(token, 50);
      await expect(
        multisigManager
          .connect(voters[1])
          .approveRedeem(
            await getLastRequestId(multisigManager, "RedeemRequested")
          )
      ).to.changeTokenBalance(token, multisigManager, -50);
    });
  });

  describe("requestVotersListChange+approveVotersListChange", () => {
    it("should allow replacing a voter", async () => {
      const {
        multisigManager,
        token,
        voters,
        accounts: [a1],
      } = await loadFixture(deployTokenWithMultisigManager);

      await multisigManager
        .connect(voters[0])
        .requestVotersListChange([a1], [voters[1]]);
      await multisigManager
        .connect(voters[1])
        .approveVotersListChange(
          await getLastRequestId(multisigManager, "VotersListChangeRequested")
        );

      // voters[1] is no longer a voting account and thus cannot request anything
      await expect(
        multisigManager.connect(voters[1]).requestIssue(token, 1000, a1)
      ).to.be.revertedWith("not a voting account");
      // a1 is now a voting account and thus can request anything
      await expect(multisigManager.connect(a1).requestIssue(token, 200, a1)).to
        .not.be.reverted;
    });

    it("should invalidate any previous requests", async () => {
      const {
        multisigManager,
        token,
        voters,
        accounts: [a1],
      } = await loadFixture(deployTokenWithMultisigManager);

      await multisigManager.connect(voters[0]).requestIssue(token, 200, a1);
      await multisigManager
        .connect(voters[0])
        .requestVotersListChange([a1], []);
      await multisigManager
        .connect(voters[1])
        .approveVotersListChange(
          await getLastRequestId(multisigManager, "VotersListChangeRequested")
        );
      await expect(
        multisigManager
          .connect(voters[1])
          .approveIssue(
            await getLastRequestId(multisigManager, "IssueRequested")
          )
      ).to.be.revertedWith("request invalidated after voters list change");
    });

    it("should not allow decreasing voters number below 3", async () => {
      const {
        multisigManager,
        voters,
        accounts: [a1],
      } = await loadFixture(deployTokenWithMultisigManager);

      await multisigManager
        .connect(voters[0])
        .requestVotersListChange([a1], [voters[1], voters[2]]);
      await expect(
        multisigManager
          .connect(voters[1])
          .approveVotersListChange(
            await getLastRequestId(multisigManager, "VotersListChangeRequested")
          )
      ).to.be.revertedWith("not enough voting accounts will remain");
    });
  });

  describe("requestOwnerChange+approveOwnerChange", () => {
    it("should change token owner address", async () => {
      const {
        multisigManager,
        token,
        voters,
        accounts: [a1],
      } = await loadFixture(deployTokenWithMultisigManager);

      await multisigManager.connect(voters[0]).requestOwnerChange(token, a1);
      await multisigManager.connect(voters[1]).approveOwnerChange(await getLastRequestId(multisigManager, 'OwnerChangeRequested'));

      await expect(token.connect(a1).pause()).to.not.be.reverted;
    });
  });

  describe("requestPause+approvePause+requestUnpause+approveUnpause", () => {
    it("should pause and unpause the token", async () => {
      const {
        multisigManager,
        token,
        voters,
        accounts: [a1],
      } = await loadFixture(deployTokenWithMultisigManager);

      await multisigManager.connect(voters[0]).requestTokenPause(token);
      await multisigManager
        .connect(voters[1])
        .approveTokenPause(
          await getLastRequestId(multisigManager, "PauseRequested")
        );

      expect(await token.paused()).to.be.true;

      await multisigManager.connect(voters[1]).requestTokenUnpause(token);
      await multisigManager
        .connect(voters[2])
        .approveTokenUnpause(
          await getLastRequestId(multisigManager, "UnpauseRequested")
        );

      expect(await token.paused()).to.be.false;
    });
  });

  describe("requestBlacklist+requestUnblacklist", () => {
    it("should blacklist and unblacklist users", async () => {
      const {
        multisigManager,
        token,
        voters,
        accounts: [a1],
      } = await loadFixture(deployTokenWithMultisigManager);

      await multisigManager.connect(voters[1]).requestBlacklist(token, a1);
      await multisigManager
        .connect(voters[0])
        .approveBlacklist(
          await getLastRequestId(multisigManager, "BlacklistRequested")
        );

      expect(await token.isBlackListed(a1)).to.be.true;

      await multisigManager.connect(voters[2]).requestUnblacklist(token, a1);
      await multisigManager
        .connect(voters[1])
        .approveUnblacklist(
          await getLastRequestId(multisigManager, "UnblacklistRequested")
        );

      expect(await token.isBlackListed(a1)).to.be.false;
    });
  });

  describe("requestBlackFundsDestruction+approveBlackFundsDestruction", () => {
    it("should destroy funds of blacklisted account", async () => {
      const {
        multisigManager,
        token,
        voters,
        supplier,
        accounts: [a1],
      } = await loadFixture(deployTokenWithMultisigManager);

      await token.connect(supplier).transfer(a1, 100);
      await multisigManager.connect(voters[0]).requestBlacklist(token, a1);
      await multisigManager
        .connect(voters[1])
        .approveBlacklist(
          await getLastRequestId(multisigManager, "BlacklistRequested")
        );
      await multisigManager
        .connect(voters[0])
        .requestBlackFundsDestruction(token, a1);
      await expect(
        multisigManager
          .connect(voters[1])
          .approveBlackFundsDestruction(
            await getLastRequestId(
              multisigManager,
              "BlackFundsDestructionRequested"
            )
          )
      ).to.changeTokenBalance(token, a1, -100);
    });
  });
});
