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
   * @returns {string}
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
            getLastRequestId(multisigManager, "VotersListChangeRequested")
          )
      ).wait();

      expect(await multisigManager.getMinApprovals()).to.equal(3);
    });
  });
});
