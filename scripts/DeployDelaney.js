const { ethers } = require('hardhat');

async function main() {
  const owner = await ethers.provider.getSigner(0);
  const poolAddress = '0x60D8A47c075E7E95cd58C7C5598208F58c89242C';
  const mudTokenAddress = '0x9922308f2d9202C0650347d06Cb2095F3dD234BE';

  const Delaney = await ethers.getContractFactory('Delaney');
  const delaney = await Delaney.deploy(owner.address, owner.address, poolAddress, mudTokenAddress);
  await delaney.waitForDeployment();
  console.log(`delaney contract deployed to ${delaney.target}`);

  {
    const price = await delaney.mudPrice();
    console.log({ price });
  }

  {
    let tx;
    tx = await delaney.setConfig('period_duration', 180); // 方便测试每个周期设为180秒
    await tx.wait();

    tx = await delaney.setConfig('period_num', 3); // 方便测试一共3周期
    await tx.wait();

    tx = await delaney.setConfig('preson_reward_min_usdt', 0); // 个人奖励阈值
    await tx.wait();

    tx = await delaney.setConfig('team_reward_min_usdt', 0); // 团队奖励阈值
    await tx.wait();

    tx = await delaney.setConfig('claim_min_usdt', 1); // 奖励领取阈值
    await tx.wait();
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
