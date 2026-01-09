const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxyAddress = process.env.PROXY_ADDRESS;
  if (!proxyAddress) throw new Error("Set PROXY_ADDRESS env to proxy address");

  const TokenVaultV3 = await ethers.getContractFactory("TokenVaultV3");
  const upgraded = await upgrades.upgradeProxy(proxyAddress, TokenVaultV3, { kind: "uups" });
  await upgraded.waitForDeployment();
  console.log("Upgraded to V3 at:", await upgraded.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
