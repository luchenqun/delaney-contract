const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("Delaney", function () {
  const mudAmount = 10000 * 1000000;
  let delaney;
  let mudToken;
  let poolMock;
  let owner;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    // 部署一个 MetaUserDAOToken 代币
    const MetaUserDAOToken = await ethers.getContractFactory(
      "MetaUserDAOToken"
    );
    mudToken = await MetaUserDAOToken.deploy(owner.address);
    await mudToken.waitForDeployment();
    console.log(`mudToken contract deployed to ${mudToken.target}`);

    // 部署 UniswapV3Pool 合约
    const UniswapV3Pool = await ethers.getContractFactory("UniswapV3Pool");
    poolMock = await UniswapV3Pool.deploy();
    await poolMock.waitForDeployment();
    console.log(`poolMock contract deployed to ${poolMock.target}`);

    // 部署 Delaney 合约
    const Delaney = await ethers.getContractFactory("Delaney");
    delaney = await Delaney.deploy(
      owner.address,
      owner.address,
      poolMock.target,
      mudToken.target
    );
    await delaney.waitForDeployment();
    console.log(`delaney contract deployed to ${delaney.target}`);
    const mintAmount = ethers.parseUnits("10000", 18);
    mudToken.mint(delaney.target, mintAmount);

    // 向用户1转移 mudToken
    await mudToken.transfer(user1.address, mudAmount);
    // 授权 delaney 合约可以转移用户的 mudToken
    await mudToken.connect(user1).approve(delaney.target, mudAmount);
  });

  describe("mudPrice", function () {
    it("should get correctly default mud price", async function () {
      const price = await delaney.mudPrice();

      const expectedAdjustedPrice = 210121;
      expect(price).to.equal(expectedAdjustedPrice);
    });
  });

  describe("delegate", function () {
    let mudPrice; // 假设 mudToken 的价格
    const minPersonInvestUsdt = 10; // 系统最低要求的 USDT
    const periodDuration = 3600; // 假设每个周期为 1 小时
    const periodNum = 2; // 假设重新质押 2 个周期

    beforeEach(async function () {
      mudPrice = await delaney.mudPrice();
      console.log("mudPrice", mudPrice);
    });

    it("should successfully delegate", async function () {
      const minUsdt = 1; // 最小 USDT 要求
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1小时后过期
      const expectUsdt = (mudAmount * Number(mudPrice)) / 1000000;

      // 调用 delegate 方法
      const tx = await delaney
        .connect(user1)
        .delegate(mudAmount, minUsdt, deadline);
      await tx.wait();

      // 验证委托信息
      const delegation = await delaney.delegations(0);
      console.log(delegation);
      expect(delegation.delegator).to.equal(user1.address);
      expect(delegation.mud).to.equal(mudAmount);
      expect(delegation.usdt).to.equal(expectUsdt);

      await expect(tx)
        .to.emit(delaney, "Delegate")
        .withArgs(
          user1.address,
          0,
          mudAmount,
          expectUsdt,
          delegation.unlockTime
        );
    });

    it("should revert if delegate is expired", async function () {
      const minUsdt = 1;
      const deadline = Math.floor(Date.now() / 1000) - 3600; // 过期时间

      await expect(
        delaney.connect(user1).delegate(mudAmount, minUsdt, deadline)
      ).to.be.revertedWith("Delegate expired");
    });

    it("should revert if usdt does not meet minimum requirement", async function () {
      const minUsdt = 10000000000; // 设置一个不合理的最小值
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      await expect(
        delaney.connect(user1).delegate(mudAmount, minUsdt, deadline)
      ).to.be.revertedWith(
        "Delegate mud corresponding usdt does not meet your minimum requirement"
      );
    });

    it("should revert if mud does not meet system minimum requirement", async function () {
      const minUsdt = 1; // 设定一个合理的最小值
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      const newMud = 100 * Number(mudPrice);

      await expect(
        delaney.connect(user1).delegate(newMud, minUsdt, deadline)
      ).to.be.revertedWith(
        "Delegate mud corresponding usdt does not meet system minimum requirement"
      );
    });
  });

  describe("claim", function () {
    const usdtAmount = ethers.parseUnits("100", 18); // 假设每次 claim 的 USDT 数量

    it("should successfully claim rewards", async function () {
      const minMud = 1;
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1小时后过期
      const rewardIds = "{}";

      const messageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "uint256", "string", "uint256"],
        [user1.address, usdtAmount, minMud, rewardIds, deadline]
      );

      const signature = await owner.signMessage(ethers.getBytes(messageHash));
      console.log(await mudToken.balanceOf(delaney.target));
      // 调用 claim 方法
      await expect(
        delaney
          .connect(user1)
          .claim(usdtAmount, minMud, rewardIds, signature, deadline)
      )
        .to.emit(delaney, "Claim")
        .withArgs(
          user1.address,
          0,
          usdtAmount,
          471157095197528,
          ethers.hexlify(signature)
        );

      // 验证用户余额
      const user1Balance = await mudToken.balanceOf(user1.address);
      expect(user1Balance).to.equal(472167095197528);
    });

    it("should revert if claim is made by non-signer", async function () {
      const minMud = 1;
      const deadline = Math.floor(Date.now() / 1000) + 3600;
      const rewardIds = "{}";

      const messageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "uint256", "string", "uint256"],
        [user1.address, usdtAmount, minMud, rewardIds, deadline]
      );

      const signature = await owner.signMessage(ethers.getBytes(messageHash));

      // 更改用户为非签名者
      await expect(
        delaney
          .connect(user2)
          .claim(usdtAmount, minMud, rewardIds, signature, deadline)
      ).to.be.revertedWith("Claim is required for signer");
    });

    it("should revert if claim is expired", async function () {
      const minMud = 1;
      const deadline = Math.floor(Date.now() / 1000) - 3600; // 过期时间
      const rewardIds = "reward1";

      const messageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "uint256", "string", "uint256"],
        [user1.address, usdtAmount, minMud, rewardIds, deadline]
      );

      const signature = await owner.signMessage(ethers.getBytes(messageHash));

      await expect(
        delaney
          .connect(user1)
          .claim(usdtAmount, minMud, rewardIds, signature, deadline)
      ).to.be.revertedWith("Claim expired");
    });

    it("should revert if claim is claimed", async function () {
      const minMud = 1;
      const deadline = Math.floor(Date.now() / 1000) + 3600;
      const rewardIds = "{}";

      const messageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "uint256", "string", "uint256"],
        [user1.address, usdtAmount, minMud, rewardIds, deadline]
      );

      const signature = await owner.signMessage(ethers.getBytes(messageHash));

      // 首次调用成功
      await delaney
        .connect(user1)
        .claim(usdtAmount, minMud, rewardIds, signature, deadline);

      // 尝试在24小时内再次调用
      await expect(
        delaney
          .connect(user1)
          .claim(usdtAmount, minMud, rewardIds, signature, deadline)
      ).to.be.revertedWith("You have claimed");
    });

    it("should revert if the mud amount does not meet the minimum requirement", async function () {
      const minMud = 1000000000000000; // 设置一个不合理的最小值
      const deadline = Math.floor(Date.now() / 1000) + 3600;
      const rewardIds = "reward1";

      const messageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "uint256", "string", "uint256"],
        [user1.address, usdtAmount, minMud, rewardIds, deadline]
      );

      const signature = await owner.signMessage(ethers.getBytes(messageHash));

      await expect(
        delaney
          .connect(user1)
          .claim(usdtAmount, minMud, rewardIds, signature, deadline)
      ).to.be.revertedWith("Claim mud does not meet your minimum requirement");
    });
  });

  describe("redelegate", function () {
    const minUsdt = 1;
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 设置截止时间为5分钟后

    beforeEach(async function () {
      // 设置用户的委托
      await delaney.connect(user1).delegate(mudAmount, minUsdt, deadline);
    });

    it("should revert if the caller is not the delegator", async function () {
      const id = 0;
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      await expect(
        delaney.connect(user2).redelegate(id, deadline)
      ).to.be.revertedWith("You aren't the delegator");
    });

    it("should revert if redelegate is expired", async function () {
      const id = 0;
      const deadline = Math.floor(Date.now() / 1000) - 3600; // 过期的截止时间

      await expect(
        delaney.connect(user1).redelegate(id, deadline)
      ).to.be.revertedWith("Redelegate expired");
    });

    it("should revert if the unlock time has not been reached", async function () {
      const id = 0;
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      await expect(
        delaney.connect(user1).redelegate(id, deadline)
      ).to.be.revertedWith("You can't redelegate yet");
    });
  });

  describe("undelegate", function () {
    const minUsdt = 1;
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 设置截止时间为5分钟后

    beforeEach(async function () {
      // 设置用户的委托
      await delaney.connect(user1).delegate(mudAmount, minUsdt, deadline);
    });

    it("should revert if the caller is not the delegator", async function () {
      const id = 0;
      const minMud = 1;
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      await expect(
        delaney.connect(user2).undelegate(id, minMud, deadline)
      ).to.be.revertedWith("You aren't the delegator");
    });

    it("should revert if undelegate is expired", async function () {
      const id = 0;
      const minMud = 1;
      const deadline = Math.floor(Date.now() / 1000) - 3600; // 过期的截止时间

      await expect(
        delaney.connect(user1).undelegate(id, minMud, deadline)
      ).to.be.revertedWith("Undelegate expired");
    });
  });

  describe("deposit", function () {
    it("should allow deposits when contract has sufficient balance", async function () {
      const depositAmount = ethers.parseUnits("1000", 18);

      const balance = await mudToken.balanceOf(user1.address);

      // 用户调用 deposit 函数
      await expect(delaney.connect(user1).deposit(depositAmount))
        .to.emit(delaney, "Deposit")
        .withArgs(user1.address, depositAmount);

      // 检查用户余额
      const userBalance = await mudToken.balanceOf(user1.address);
      expect(userBalance).to.equal(depositAmount + balance);

      // 检查合约的 depositMud 状态
      const stat = await delaney.stat();
      expect(stat.depositMud).to.equal(depositAmount);
    });

    it("should revert if contract has insufficient balance", async function () {
      const depositAmount = ethers.parseUnits("60000", 18); // 超过合约余额

      // 尝试调用 deposit 函数并检查是否抛出错误
      await expect(
        delaney.connect(user1).deposit(depositAmount)
      ).to.be.revertedWith("Insufficient balance in the contract");
    });
  });

  describe("profit", function () {
    beforeEach(async function () {
      await delaney.pause();
    });
    it("should allow the owner to profit successfully", async function () {
      const mudAmount = 1000;

      await delaney.unpause();

      // 记录合约中存款的初始值
      const beforeStat = await delaney.stat();
      initialProfitMud = beforeStat.profitMud;
      const balance = await mudToken.balanceOf(delaney.target);

      // 调用 profit 方法
      const tx = await delaney.connect(owner).profit(mudAmount);
      await tx.wait();

      const contractBalance = await mudToken.balanceOf(delaney.target);
      expect(contractBalance).to.equal(balance - BigInt(mudAmount));

      const afterStat = await delaney.stat();
      expect(afterStat.profitMud).to.equal(
        initialProfitMud + BigInt(mudAmount)
      );

      // 验证事件是否被正确发出
      await expect(tx)
        .to.emit(delaney, "Profit")
        .withArgs(owner.address, mudAmount);
    });

    it("should revert if the contract has insufficient balance", async function () {
      const mudAmount = ethers.parseUnits("100000", 18); // 用户要提取的 MUD 数量

      // 确保合约未暂停
      await delaney.unpause(); // 如果合约是暂停的，先调用 unpause

      // 调用 profit 方法，合约中没有足够的 MUD 代币
      await expect(delaney.connect(owner).profit(mudAmount)).to.be.revertedWith(
        "Insufficient balance in the contract"
      ); // 验证是否会 revert
    });
  });

  describe("pause", function () {
    beforeEach(async function () {
      await delaney.pause();
    });
    it("should allow the owner to pause the contract", async function () {
      // 确保合约未暂停
      await delaney.unpause(); // 确保合约处于正常状态

      // 调用 pause 方法
      await delaney.connect(owner).pause();

      // 验证合约是否被暂停
      expect(await delaney.paused()).to.be.true; // 假设合约有 paused() 方法
    });
  });

  describe("unpause", function () {
    it("should allow the owner to unpause the contract", async function () {
      // 首先暂停合约
      await delaney.connect(owner).pause();

      // 调用 unpause 方法
      await delaney.connect(owner).unpause();

      // 验证合约是否恢复
      expect(await delaney.paused()).to.be.false; // 假设合约有 paused() 方法
    });
  });
});
