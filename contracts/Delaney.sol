// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// 添加 Uniswap V2 接口
interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function token0() external view returns (address);

    function token1() external view returns (address);
}

contract Delaney is Pausable, Ownable {
    event Delegate(
        address indexed delegator,
        uint256 id,
        uint256 mud,
        uint256 usdt,
        uint256 unlockTime
    );

    event Claim(
        address indexed delegator,
        uint256 id,
        uint256 usdt,
        uint256 mud,
        string signature
    );

    event Redelegate(
        address indexed delegator,
        uint256 id,
        uint256 usdt,
        uint256 mud
    );

    event Undelegate(
        address indexed delegator,
        uint256 id,
        uint256 usdt,
        uint256 mud
    );

    event AddedBlackList(address indexed evilUser, bool isBlack);

    event SetConfig(address indexed owner, string key, uint256 value);

    event Deposit(address indexed Depositer, uint256 mud);

    event Profit(address indexed owner, uint256 mud);

    struct Delegation {
        uint id;
        address delegator;
        uint mud; // 每次质押数量
        uint usdt; // 数量对应usdt的价值
        uint backMud; // 取消质押返回对应的mud
        uint periodDuration;
        uint periodNum;
        uint unlockTime; // 解锁时间
        bool withdrew;
    }

    struct Claimant {
        uint id;
        address delegator;
        uint usdt;
        uint minMud;
        uint mud;
        string rewardIds;
        string signature;
        uint deadline;
    }

    struct Stat {
        uint delegateCount;
        uint delegateUsdt;
        uint delegateMud;
        uint claimCount;
        uint claimUsdt;
        uint claimMud;
        uint undelegateCount;
        uint undelegateUsdt;
        uint undelegateMud;
        uint depositMud;
        uint profitMud;
    }

    address public pairAddress;
    address public signerAddress;
    address public usdtAddress;

    bool public pausedBusiness;
    mapping(uint => Delegation) public delegations;
    mapping(address => uint) public lastClaimTimestamp;
    mapping(uint => Claimant) public claimants;
    mapping(uint => uint) public undelegateIds;
    mapping(string => bool) public signatures;
    mapping(string => uint) public configs;
    mapping(address => bool) public blacklist;
    Stat public stat;

    modifier whenNotPausedBusiness() {
        require(!pausedBusiness, "Business is paused");
        _;
    }

    constructor(
        address initialOwner,
        address initalSignerAddress,
        address initalPairAddress,
        address initialUsdtAddress
    ) Ownable(initialOwner) {
        signerAddress = initalSignerAddress;
        pairAddress = initalPairAddress;
        usdtAddress = initialUsdtAddress;

        configs["fee"] = 0;
        configs["period_duration"] = 15 * 24 * 3600;
        configs["period_num"] = 8;
        configs["period_reward_ratio"] = 5;
        configs["person_reward_level1"] = 3;
        configs["person_reward_level2"] = 4;
        configs["person_reward_level3"] = 5;
        configs["person_reward_level4"] = 6;
        configs["person_reward_level5"] = 7;
        configs["team_reward_level1"] = 3;
        configs["team_reward_level2"] = 6;
        configs["team_reward_level3"] = 9;
        configs["team_reward_level4"] = 12;
        configs["team_reward_level5"] = 15;
        configs["person_invest_min_usdt"] = 100 * 1000000;
        configs["person_reward_min_usdt"] = 100 * 1000000;
        configs["team_reward_min_usdt"] = 1000 * 1000000;
        configs["claim_min_usdt"] = 50 * 1000000;
        configs["claim_max_usdt"] = 10000 * 1000000;
        configs["claim_gap"] = 24 * 3600;
        configs["team_level1_sub_usdt"] = 5000 * 1000000;
        configs["team_level1_team_usdt"] = 20000 * 1000000;
    }

    function mudPrice() public view returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        address token0 = pair.token0();

        // 确定MUD(native token, 18位小数)和USDT(6位小数)的储备量
        uint256 mudReserve;
        uint256 usdtReserve;

        if (token0 == usdtAddress) {
            usdtReserve = reserve0;
            mudReserve = reserve1;
        } else {
            mudReserve = reserve0;
            usdtReserve = reserve1;
        }

        // 计算价格 (MUD/USDT)
        // 我们要计算1 MUD能买多少USDT并保留18位精度
        uint256 price = (usdtReserve * 1e18) / mudReserve;

        // 扣除0.3%手续费
        return (price * 997) / 1000;
    }

    // mudToUsdt
    function mudToUsdt(uint mud) public view returns (uint) {
        return (mud * mudPrice()) / 1e18;
    }

    // usdtToMud
    function usdtToMud(uint usdt) public view returns (uint) {
        return (usdt * 1e18) / mudPrice();
    }

    // 质押mud
    function delegate(
        uint minUsdt,
        uint deadline
    ) public payable whenNotPaused whenNotPausedBusiness {
        require(!blacklist[msg.sender], "You have been blacked");
        require(msg.value > 0, "Must send MUD");

        uint usdt = mudToUsdt(msg.value);

        require(deadline >= block.timestamp, "Delegate expired");
        require(
            usdt >= minUsdt,
            "Delegate mud corresponding usdt does not meet your minimum requirement"
        );
        require(
            usdt >= configs["person_invest_min_usdt"],
            "Delegate mud corresponding usdt does not meet system minimum requirement"
        );

        uint periodDuration = configs["period_duration"];
        uint periodNum = configs["period_num"];

        Delegation memory delegation;
        uint unlockTime = block.timestamp + periodDuration * periodNum;
        delegation.id = stat.delegateCount;
        delegation.delegator = msg.sender;
        delegation.mud = msg.value;
        delegation.usdt = usdt;
        delegation.unlockTime = unlockTime;
        delegation.periodDuration = periodDuration;
        delegation.periodNum = periodNum;
        delegation.withdrew = false;

        delegations[stat.delegateCount] = delegation;

        stat.delegateCount += 1;
        stat.delegateMud += msg.value;
        stat.delegateUsdt += usdt;

        emit Delegate(msg.sender, delegation.id, msg.value, usdt, unlockTime);
    }

    // 领取奖励
    function claim(
        uint usdt,
        uint minMud,
        string memory rewardIds,
        bytes memory signature,
        uint deadline
    ) public whenNotPaused {
        require(!blacklist[msg.sender], "You have been blacked");

        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(
                        msg.sender,
                        usdt,
                        minMud,
                        rewardIds,
                        deadline
                    )
                )
            )
        );
        address signer = recoverSigner(ethSignedMessageHash, signature);
        require(signer == signerAddress, "Claim is required for signer");

        string memory hexSignature = bytesToHexString(signature);

        require(
            usdt >= configs["claim_min_usdt"],
            "The amount of claim does not meet the minimum amount"
        );
        require(
            usdt <= configs["claim_max_usdt"],
            "The amount of claim exceed the maximum amount"
        );
        require(
            block.timestamp - lastClaimTimestamp[msg.sender] >=
                configs["claim_gap"],
            "You can claim only once per day"
        );
        require(deadline >= block.timestamp, "Claim expired");
        require(!signatures[hexSignature], "You have claimed");

        uint mud = usdtToMud((usdt * (100 - configs["fee"])) / 100);
        require(
            mud >= minMud,
            "Claim mud does not meet your minimum requirement"
        );
        require(
            address(this).balance >= mud,
            "Insufficient balance in the contract"
        );

        (bool success, ) = msg.sender.call{value: mud}("");
        require(success, "Transfer failed");

        Claimant memory claimant;
        claimant.id = stat.claimCount;
        claimant.delegator = msg.sender;
        claimant.usdt = usdt;
        claimant.minMud = minMud;
        claimant.mud = mud;
        claimant.rewardIds = rewardIds;
        claimant.signature = hexSignature;
        claimant.deadline = deadline;

        claimants[stat.claimCount] = claimant;

        signatures[hexSignature] = true;
        lastClaimTimestamp[msg.sender] = block.timestamp;

        stat.claimCount += 1;
        stat.claimMud += mud;
        stat.claimUsdt += usdt;

        emit Claim(msg.sender, claimant.id, usdt, mud, hexSignature);
    }

    // 到期重复质押
    function redelegate(
        uint id,
        uint deadline
    ) public whenNotPaused whenNotPausedBusiness {
        require(!blacklist[msg.sender], "You have been blacked");

        Delegation storage delegation = delegations[id];

        require(delegation.delegator == msg.sender, "You aren't the delegator");
        require(!delegation.withdrew, "You have withdrew");
        require(deadline >= block.timestamp, "Redelegate expired");
        require(
            block.timestamp > delegation.unlockTime,
            "You can't redelegate yet"
        );

        uint periodDuration = configs["period_duration"];
        uint periodNum = configs["period_num"];

        uint unlockTime = block.timestamp + periodDuration * periodNum;
        delegation.unlockTime = unlockTime;
        delegation.periodDuration = periodDuration;
        delegation.periodNum = periodNum;

        emit Redelegate(msg.sender, id, delegation.usdt, delegation.mud);
    }

    // 结束质押
    function undelegate(
        uint id,
        uint minMud,
        uint deadline
    ) public whenNotPaused {
        require(!blacklist[msg.sender], "You have been blacked");

        Delegation storage delegation = delegations[id];
        require(delegation.delegator == msg.sender, "You aren't the delegator");

        uint mud = usdtToMud(delegation.usdt);

        require(!delegation.withdrew, "You have withdrew");
        require(deadline >= block.timestamp, "Undelegate expired");
        require(
            block.timestamp > delegation.unlockTime,
            "You can't undelegate yet"
        );
        require(
            mud >= minMud,
            "Undelegate mud does not meet your minimum requirement"
        );
        require(
            address(this).balance >= mud,
            "Insufficient balance in the contract"
        );

        delegations[id].withdrew = true;
        delegations[id].backMud = mud;

        (bool success, ) = msg.sender.call{value: mud}("");
        require(success, "Transfer failed");

        undelegateIds[stat.undelegateCount] = id;
        stat.undelegateCount += 1;
        stat.undelegateMud += mud;
        stat.undelegateUsdt += delegation.usdt;

        emit Undelegate(msg.sender, id, delegation.usdt, mud);
    }

    // 存储
    function deposit() public payable whenNotPaused {
        require(msg.value > 0, "Must send MUD");
        stat.depositMud += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // 利润提取
    function profit(uint mud) public onlyOwner whenNotPaused {
        require(
            address(this).balance >= mud,
            "Insufficient balance in the contract"
        );

        (bool success, ) = msg.sender.call{value: mud}("");
        require(success, "Transfer failed");

        stat.profitMud += mud;
        emit Profit(msg.sender, mud);
    }

    function setConfig(
        string memory key,
        uint value
    ) public onlyOwner whenNotPaused {
        if (compareString(key, "period_num")) {
            require(value > 0, "Period duration must granter than 0");
        }
        if (compareString(key, "fee")) {
            require(value < 100, "Fee must less than 100");
        }

        configs[key] = value;
        emit SetConfig(msg.sender, key, value);
    }

    function getConfigs() public view returns (uint[] memory) {
        uint[] memory values = new uint[](22);
        values[0] = configs["fee"];
        values[1] = configs["period_duration"];
        values[2] = configs["period_num"];
        values[3] = configs["period_reward_ratio"];
        values[4] = configs["person_reward_level1"];
        values[5] = configs["person_reward_level2"];
        values[6] = configs["person_reward_level3"];
        values[7] = configs["person_reward_level4"];
        values[8] = configs["person_reward_level5"];
        values[9] = configs["team_reward_level1"];
        values[10] = configs["team_reward_level2"];
        values[11] = configs["team_reward_level3"];
        values[12] = configs["team_reward_level4"];
        values[13] = configs["team_reward_level5"];
        values[14] = configs["person_invest_min_usdt"];
        values[15] = configs["person_reward_min_usdt"];
        values[16] = configs["team_reward_min_usdt"];
        values[17] = configs["claim_min_usdt"];
        values[18] = configs["claim_max_usdt"];
        values[19] = configs["claim_gap"];
        values[20] = configs["team_level1_sub_usdt"];
        values[21] = configs["team_level1_team_usdt"];
        return values;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function pauseBusiness() public onlyOwner {
        pausedBusiness = true;
    }

    function unpauseBusiness() public onlyOwner {
        pausedBusiness = false;
    }

    function addBlackList(
        address user,
        bool isBlack
    ) public onlyOwner whenNotPaused {
        blacklist[user] = isBlack;
        emit AddedBlackList(user, isBlack);
    }

    function recoverSigner(
        bytes32 ethSignedMessageHash,
        bytes memory signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := byte(0, mload(add(sig, 0x60)))
        }
    }

    function bytesToHexString(
        bytes memory data
    ) public pure returns (string memory) {
        bytes memory hexString = new bytes(2 * data.length + 2);
        hexString[0] = "0";
        hexString[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            uint8 b = uint8(data[i]);
            hexString[2 * i + 2] = _byteToHex(b / 16);
            hexString[2 * i + 3] = _byteToHex(b % 16);
        }
        return string(hexString);
    }

    function _byteToHex(uint8 b) private pure returns (bytes1) {
        if (b < 10) {
            return bytes1(uint8(b + 48));
        } else {
            return bytes1(uint8(b + 87));
        }
    }

    function compareString(
        string memory a,
        string memory b
    ) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    receive() external payable {}
}
