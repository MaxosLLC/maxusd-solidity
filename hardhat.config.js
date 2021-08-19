require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-gas-reporter");
require("hardhat-abi-exporter");
require("solidity-coverage");
require("@nomiclabs/hardhat-etherscan");
require('dotenv').config();

// *** PK STATED BELOW IS DUMMY PK EXCLUSIVELY FOR TESTING PURPOSES ***
// const PK = `0x${"32c069bf3d38a060eacdc072eecd4ef63f0fc48895afbacbe185c97037789875"}`

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

const infuraKey = process.env.INFURA_KEY;
const mnemonic = process.env.MNEMONIC;
const alchemyKey = process.env.ALCHEMY_KEY;

function nodeUrl(network) {
  return `https://${network}.infura.io/v3/${infuraKey}`;
}

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
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${alchemyKey}`,
        blockNumber: 13005280,
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
      // Infura public nodes
      url: 'https://rinkeby.infura.io/v3/34ee2e319e7945caa976d4d1e24db07f',
      accounts: [process.env.PK || PK],
      chainId: 4,
      gasPrice: 40000000000,
      timeout: 50000
    },
    ropsten: {
      // Infura public nodes
      url: 'https://ropsten.infura.io/v3/34ee2e319e7945caa976d4d1e24db07f',
      accounts: [process.env.PK || PK],
      chainId: 3,
      gasPrice: 40000000000,
      timeout: 50000
    },
    mainnet: {
      // Infura public nodes
      url: 'https://mainnet.infura.io/v3/1692a3b8ad92406189c2c7d2b01660bc',
      accounts: [process.env.PK || PK],
      chainId: 1,
      gasPrice: 115000000000, // 44 GWEI gas price for deployment.
      timeout: 10000000
    },
    local: {
      url: 'http://localhost:8545',
    },
    coverage: {
      url: "http://127.0.0.1:8555",
    },
  },
  solidity: {
    version: "0.8.3",
    settings: {
      optimizer: {
        enabled: true,
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
  mocha: {
    timeout: 50000,
  },
  abiExporter: {
    path: "./abi",
    clear: true,
    flat: true,
    spacing: 2,
  },
  etherscan: {
    apiKey: process.env.API_KEY
  }
};
