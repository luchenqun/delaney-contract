const { ethers } = require('hardhat');

async function main() {
  const owner = await ethers.provider.getSigner(0);
  const pairAddress = '0x7F202fda32D43F726C77E2B3288e6c6f3e7e341A';
  const usdtAddress = '0x592d157a0765b43b0192Ba28F4b8cd4F50E326cF';

  const Delaney = await ethers.getContractFactory('Delaney');
  const delaney = await Delaney.deploy(owner.address, owner.address, pairAddress, usdtAddress);
  await delaney.waitForDeployment();
  console.log(`delaney contract deployed to ${delaney.target}`);

  {
    const price = await delaney.mudPrice();
    console.log({ price });
  }

  {
    let tx;
    tx = await delaney.setConfig('preson_invest_min_usdt', 1000000); // 个人最小投资额度
    await tx.wait();

    tx = await delaney.setConfig('period_duration', 30); // 方便测试每个周期设为6秒
    await tx.wait();

    tx = await delaney.setConfig('period_num', 3); // 方便测试一共3周期
    await tx.wait();

    tx = await delaney.setConfig('preson_reward_min_usdt', 0); // 个人奖励阈值
    await tx.wait();

    tx = await delaney.setConfig('team_reward_min_usdt', 0); // 团队奖励阈值
    await tx.wait();

    tx = await delaney.setConfig('team_level1_sub_usdt', 1); // 成为1星的直推条件
    await tx.wait();

    tx = await delaney.setConfig('team_level1_team_usdt', 1); // 成为1星的团队条件
    await tx.wait();

    tx = await delaney.setConfig('claim_min_usdt', 1000000); // 奖励领取阈值
    await tx.wait();
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
