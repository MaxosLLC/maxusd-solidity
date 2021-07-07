const fs = require("fs");
const path = require("path");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-gas-reporter");
require("hardhat-abi-exporter");
require("solidity-coverage");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// REQUIRED TO ENSURE METADATA IS SAVED IN DEPLOYMENTS (because solidity-coverage disable it otherwise)
const { TASK_COMPILE_GET_COMPILER_INPUT } = require("hardhat/builtin-tasks/task-names");
task(TASK_COMPILE_GET_COMPILER_INPUT).setAction(async (_, bre, runSuper) => {
  const input = await runSuper();
  input.settings.metadata.useLiteralContent = bre.network.name !== "coverage";
  return input;
});

const infuraKey = process.env.INFURA_KEY || "";

function nodeUrl(network) {
  return `https://${network}.infura.io/v3/${infuraKey}`;
}

let mnemonic = process.env.MNEMONIC || "";
const accounts = mnemonic
  ? {
      mnemonic,
    }
  : undefined;

module.exports = {
  defaultNetwork: "hardhat",
  gasReporter: {
    showTimeSpent: true,
    currency: "USD",
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
        evmVersion: "byzantium",
      },
    },
    kovan: {
      accounts,
      url: nodeUrl("kovan"),
    },
    goerli: {
      accounts,
      url: nodeUrl("goerli"),
    },
    rinkeby: {
      accounts,
      url: nodeUrl("rinkeby"),
    },
    ropsten: {
      accounts,
      url: nodeUrl("ropsten"),
    },
    mainnet: {
      accounts,
      url: nodeUrl("mainnet"),
    },
    coverage: {
      url: "http://127.0.0.1:8555",
    },
  },
  solidity: {
    version: "0.8.3",
    settings: {
      optimizer: {
        enabled: false,
        runs: 200,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    coverage: "./coverage",
    coverageJson: "./coverage.json",
    artifacts: "./artifacts",
  },
  namedAccounts: {
    deployer: 0,
  },
  mocha: {
    timeout: 50000,
  },
  abiExporter: {
    path: "./abi",
    clear: true,
    flat: true,
    spacing: 2,
  },
};
