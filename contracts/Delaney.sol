// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// 需求：管理员可以更新星级

contract Delaney {
    address public zeroAddress = address(0);
    address public owner;
    uint curRef; // 系统当前推荐码
    uint ownerRef; // 项目方推荐码

    uint minPersonInvestUsdt = 100;
    uint minTeamInvestUsdt = 1000;
    uint maxStar = 5;

    struct Delegate {
        uint id;
        uint timestamp; // 质押时间
        uint height;
        uint amount; // 每次质押数量
        uint usdt; // 数量对应usdt的价值
        bool redelegate;
    }

    struct Delegation {
        address user; // 用户地址
        address parent; // 推荐人
        Delegate[] delegates;
        address[] children; // 子节点
        uint star; // 星级
        uint[6] chindStars; // 每个等级对应的星数
        uint selfDelegateMud; // 自己质押MUD数量
        uint teamDelegateMud; // 团队质押MUD数量
        uint directDelegateMud; // 直推质押MUD数量
        uint selfDelegateUsdt; // 自己质押的MUD对应USDT数量
        uint teamDelegateUsdt; // 团队质押的MUD对应USDT数量
        uint directDelegateUsdt; // 直推质押的MUD对应USDT数量
        uint ref; // 我的邀请码（只有质押才能产生）
        uint tierDynamicReward; // 层级动态奖励
        uint teamDynamicReward; // 团队动态奖励
        uint withdrawDynamicReward; // 已领取动态奖励
    }

    mapping(address => Delegation) delegations;

    mapping(address => uint) userToRef;
    mapping(uint => address) refToUser;
    mapping(address => uint) binds; // 用户用的哪个推荐码

    constructor(address _owner, uint startRef) {
        require(startRef > 0, "startRef > 0");
        owner = _owner;
        curRef = startRef;
        ownerRef = startRef;
    }

    function teamRewardRaito(uint star) public pure returns (uint) {
        if (star == 5) return 15;
        if (star == 4) return 12;
        if (star == 3) return 9;
        if (star == 2) return 6;
        if (star == 1) return 3;
        return 0;
    }

    function bind(uint ref) public {
        require(ref > 0 && ref <= curRef, "ref > 0 && ref <= curRef");
        require(
            binds[msg.sender] == 0,
            "changing the ref code is not allowed."
        );
        binds[msg.sender] = ref;
    }

    function delegate(uint amount) public {
        uint usdt = amount; // 通过 Uniswap 拿到 USDT 的价格
        uint ref = binds[msg.sender];

        require(usdt > 100, "usdt > 100");

        address parent = msg.sender != owner ? refToUser[ref] : zeroAddress;
        if (msg.sender != owner) {
            require(parent != zeroAddress, "you ref is not exist");
            require(ref > 0, "you have not bind an invitation code yet");
        }

        Delegation storage delegation = delegations[msg.sender];
        delegation.user = msg.sender;
        delegation.parent = parent;
        delegation.delegates.push(
            Delegate({
                timestamp: block.timestamp,
                amount: amount,
                usdt: usdt,
                id: delegation.delegates.length
            })
        );
        delegation.selfDelegateMud += amount;
        delegation.selfDelegateUsdt += usdt;

        // 第一次质押需要给自己产生一个邀请码
        if (delegation.ref == 0) {
            if (msg.sender == owner) {
                delegation.ref = ownerRef;
            } else {
                curRef = curRef + 1;
                delegation.ref = curRef;
            }

            refToUser[delegation.ref] = msg.sender;
            userToRef[msg.sender] = delegation.ref;

            delegation.chindStars[0] = delegation.chindStars[0] + 1; // 多1个0星的用户
            delegations[msg.sender] = delegation;
        }

        // 将自己加入到上级的子节点列表里面
        // 更新直推相关数据
        if (msg.sender != owner) {
            Delegation storage parentDelegation = delegations[parent];
            bool find = false;
            for (uint i = 0; i < parentDelegation.children.length; i++) {
                if (parentDelegation.children[i] == msg.sender) {
                    find = true;
                }
            }
            parentDelegation.children.push(msg.sender);
            parentDelegation.directDelegateMud += amount;
            parentDelegation.directDelegateUsdt += usdt;
        }

        // 往上发放奖励
        uint8 depth = 5; // 最多奖励5层
        uint8 ratio = 3; // 从3%开始奖励
        uint startRef = ref;
        for (uint8 i = 0; i < depth; i++) {
            Delegation storage curDelegation = delegations[refToUser[startRef]];
            // 有可能不够5层，就已经到达了顶点，那么停止发放奖励
            if (curDelegation.parent == zeroAddress) {
                break;
            }
            // 发放层级奖励
            curDelegation.tierDynamicReward += (amount * ratio) / 100;
            ratio += 1;

            // 继续往上迭代
            startRef = curDelegation.ref;
        }

        // 更新团队质押的数量以及星级
        startRef = ref;
        uint preStar = 0; // 0表示孩子没有升级
        while (true) {
            Delegation storage curDelegation = delegations[refToUser[startRef]];
            if (curDelegation.parent == zeroAddress) {
                break;
            }
            // 逐级往上更新团队的mud数量以及usdt数量
            curDelegation.teamDelegateMud += amount;
            curDelegation.teamDelegateUsdt += usdt;

            if (preStar >= 1) {
                // 孩子升星了，看看自己能不能也升一把
                curDelegation.chindStars[preStar - 1] -= 1;
                curDelegation.chindStars[preStar] += 1;

                // 如果刚好相差一级，且孩子升完之后是2个，则自己也要升级，比如：
                // 如果孩子从0个一星到1个一星，自己不升级
                // 如果孩子从1个一星到2个一星，自己升级
                // 如果孩子从2个一星到3个一星，自己已经升级过了，不再升级
                // 注意: 不能跨越升级，比如孩子是一星，自己本身已经是四星了，那么不能从四星升级到五星
                if (
                    curDelegation.star == preStar &&
                    curDelegation.chindStars[preStar] == 2 &&
                    curDelegation.star == preStar + 1
                ) {
                    // 注意最大只能是五星
                    curDelegation.star = curDelegation.star >= maxStar
                        ? maxStar
                        : curDelegation.star + 1;
                    preStar = curDelegation.star;
                }
            } else if (curDelegation.star == 0) {
                // 看看自己是否需要升星(理论上只要)
                if (
                    curDelegation.directDelegateUsdt >= 5000 &&
                    curDelegation.teamDelegateUsdt >= 20000
                ) {
                    curDelegation.star = 1;
                    preStar = curDelegation.star;
                }
            } else {
                preStar = 0; // 本次自己没有升星清空升星变量
            }

            // 继续往上迭代
            startRef = curDelegation.ref;
        }

        // 开始发放团队奖励
        startRef = ref;
        preStar = 0;
        uint preRaito = 0;
        while (true) {
            Delegation storage curDelegation = delegations[refToUser[startRef]];
            // 如果星数相同，我们只管离投资者最近的
            if (curDelegation.star > preStar) {
                uint curRaito = teamRewardRaito(curDelegation.star);
                uint teamRaito = curRaito - preRaito;
                curDelegation.teamDynamicReward += (amount * teamRaito) / 100;

                preStar = curDelegation.star;
                preRaito = curRaito;
            }

            // 迭代到五星了
            if (curDelegation.star == maxStar) {
                break;
            }

            // 继续往上迭代
            startRef = curDelegation.ref;

            if (curDelegation.parent == zeroAddress) {
                break;
            }
        }
    }
}
