const { ethers } = require("hardhat");

const V2_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

async function swapETHForExactTokens(amountIn, amountExactOut, token, recipient, signer) {
  const v2Router = await ethers.getContractAt("IUniswapV2Router02", V2_ROUTER, signer);
  const weth = await v2Router.WETH();
  const timestamp = new Date().getTime();
  await v2Router.swapETHForExactTokens(
    amountExactOut,
    [weth, token],
    recipient,
    Math.round(timestamp / 1000) + 10 * 60,
    {
      value: amountIn,
    },
  );
}

module.exports = {
  swapETHForExactTokens,
};
