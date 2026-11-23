const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const Factory = await hre.ethers.getContractFactory("OmniLitFinanceV2");
  const contract = await Factory.deploy();
  await contract.waitForDeployment();
  const addr = await contract.getAddress();
  console.log("DEPLOYED_ADDRESS=" + addr);
  fs.writeFileSync("deployed-address.txt", addr);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
