const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const token = await MockERC20.deploy("MockToken", "MTK");
  await token.waitForDeployment();
  console.log("MockERC20:", await token.getAddress());

  // Mint some tokens to deployer for testing
  await (await token.mint(deployer.address, ethers.parseUnits("1000000", 18))).wait();

  const TokenVaultV1 = await ethers.getContractFactory("TokenVaultV1");
  const depositFeeBps = 500; // 5%
  const proxy = await upgrades.deployProxy(TokenVaultV1, [await token.getAddress(), deployer.address, depositFeeBps], {
    kind: "uups",
    initializer: "initialize",
  });
  await proxy.waitForDeployment();
  console.log("TokenVault Proxy (V1):", await proxy.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
