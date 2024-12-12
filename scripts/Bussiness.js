const { ethers } = require('hardhat');

async function main() {
  const owner = await ethers.provider.getSigner(0);
  const usdtAddress = '0x592d157a0765b43b0192Ba28F4b8cd4F50E326cF';

  const UniswapV2Pair = await ethers.getContractFactory('UniswapV2Pair');
  const pair = await UniswapV2Pair.deploy();
  await pair.waitForDeployment();
  console.log(`UniswapV2Pair contract deployed to ${pair.target}`);

  const Delaney = await ethers.getContractFactory('Delaney');
  const delaney = await Delaney.deploy(owner.address, owner.address, pair.target, usdtAddress);
  await delaney.waitForDeployment();
  console.log(`delaney contract deployed to ${delaney.target}`);

  {
    const reserves = await pair.getReserves();
    console.log({ reserves });
  }

  {
    const price = await delaney.mudPrice();
    console.log({ price });
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
