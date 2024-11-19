const { ethers } = require('hardhat');

async function main() {
  const owner = await ethers.provider.getSigner(0);

  const MetaUserDAOToken = await ethers.getContractFactory('MetaUserDAOToken');
  const mudToken = await MetaUserDAOToken.deploy(owner.address);
  await mudToken.waitForDeployment();
  console.log(`mudToken contract deployed to ${mudToken.target}`);

  const UniswapV3Pool = await ethers.getContractFactory('UniswapV3Pool');
  const pool = await UniswapV3Pool.deploy();
  await pool.waitForDeployment();
  console.log(`pool contract deployed to ${pool.target}`);

  const Delaney = await ethers.getContractFactory('Delaney');
  const delaney = await Delaney.deploy(owner.address, pool.target, mudToken.target, owner.address);
  await delaney.waitForDeployment();
  console.log(`delaney contract deployed to ${delaney.target}`);

  {
    const slot0 = await pool.slot0();
    console.log({ slot0 });
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
