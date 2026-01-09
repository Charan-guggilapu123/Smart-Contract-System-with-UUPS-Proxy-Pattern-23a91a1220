const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxyAddress = process.env.PROXY_ADDRESS;
  if (!proxyAddress) throw new Error("Set PROXY_ADDRESS env to proxy address");

  const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");
  const upgraded = await upgrades.upgradeProxy(proxyAddress, TokenVaultV2, { kind: "uups" });
  await upgraded.waitForDeployment();
  console.log("Upgraded to V2 at:", await upgraded.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
