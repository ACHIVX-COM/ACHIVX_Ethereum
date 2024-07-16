const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MultisigManagedToken", (m) => {
  const voters = m.getParameter("voters");

  const initialSupply = m.getParameter("initialSupply", 0);
  const supplier = m.getParameter("supplier");
  const name = m.getParameter("name", "ACHIVX Token");
  const symbol = m.getParameter("symbol", "ACHIVX");
  const decimals = m.getParameter("decimals", 6);

  const managerContract = m.contract("MultisigManager", [voters]);

  const tokenContract = m.contract("Token", [
    managerContract,
    initialSupply,
    supplier,
    name,
    symbol,
    decimals,
  ]);

  return { managerContract, tokenContract };
});
