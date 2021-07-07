/* eslint-disable no-console */

import { ethers } from 'hardhat'

async function main() {
  const Test = await ethers.getContractFactory('Test')
  const test = await Test.deploy()
  await test.deployed()
  console.log('Test contract deployed to:', test.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
