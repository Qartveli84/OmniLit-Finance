const { ethers } = require("ethers");
const solc = require("solc");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

function compileContract() {
  const contractPath = path.join(__dirname, "..", "contracts", "OmniLitFinance.sol");
  const source = fs.readFileSync(contractPath, "utf8");

  const input = {
    language: "Solidity",
    sources: {
      "OmniLitFinance.sol": { content: source }
    },
    settings: {
      optimizer: { enabled: true, runs: 200 },
      outputSelection: {
        "*": {
          "*": ["abi", "evm.bytecode.object"]
        }
      }
    }
  };

  const compiled = JSON.parse(solc.compile(JSON.stringify(input)));
  if (compiled.errors) {
    const fatal = compiled.errors.filter((e) => e.severity === "error");
    if (fatal.length > 0) {
      throw new Error("Solidity compile error: " + fatal.map((e) => e.formattedMessage).join("\n"));
    }
  }

  const contractOutput = compiled.contracts["OmniLitFinance.sol"]["OmniLitFinance"];
  return {
    abi: contractOutput.abi,
    bytecode: "0x" + contractOutput.evm.bytecode.object
  };
}

async function main() {
  const pk = (process.env.PRIVATE_KEY || "").trim();
  if (!pk || pk === "YOUR_TESTNET_PRIVATE_KEY_HERE") {
    throw new Error("Put your real PRIVATE_KEY inside .env first!");
  }

  const provider = new ethers.JsonRpcProvider("https://rpc.testnet.liteforge.zeeve.net/");
  const wallet = new ethers.Wallet(pk, provider);
  console.log("Deploying OmniLitFinance with:", wallet.address);

  const { abi, bytecode } = compileContract();
  const factory = new ethers.ContractFactory(abi, bytecode, wallet);
  const contract = await factory.deploy();
  await contract.waitForDeployment();

  const addr = await contract.getAddress();
  console.log("OmniLitFinance deployed at:", addr);

  const htmlPath = path.join(__dirname, "..", "public", "index.html");
  let html = fs.readFileSync(htmlPath, "utf8");
  html = html.replace(/__CONTRACT_ADDRESS__/g, addr);
  fs.writeFileSync(htmlPath, html, "utf8");
  console.log("Updated public/index.html with contract:", addr);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
