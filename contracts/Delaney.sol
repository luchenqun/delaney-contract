// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = a * b
        // Compute the product mod 2**256 and mod 2**256 - 1
        // then use the Chinese Remainder Theorem to reconstruct
        // the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2**256 + prod0
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        // Make sure the result is less than 2**256.
        // Also prevents denominator == 0
        require(denominator > prod1);

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0]
        // Compute remainder using mulmod
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        // Subtract 256 bit number from 512 bit number
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator
        // Compute largest power of two divisor of denominator.
        // Always >= 1.
        uint256 twos = denominator & (~denominator + 1);
        // Divide denominator by power of two
        assembly {
            denominator := div(denominator, twos)
        }

        // Divide [prod1 prod0] by the factors of two
        assembly {
            prod0 := div(prod0, twos)
        }
        // Shift in bits from prod1 into prod0. For this we need
        // to flip `twos` such that it is 2**256 / twos.
        // If twos is zero, then it becomes one
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        // Invert denominator mod 2**256
        // Now that denominator is an odd number, it has an inverse
        // modulo 2**256 such that denominator * inv = 1 mod 2**256.
        // Compute the inverse by starting with a seed that is correct
        // correct for four bits. That is, denominator * inv = 1 mod 2**4
        uint256 inv = (3 * denominator) ^ 2;
        // Now use Newton-Raphson iteration to improve the precision.
        // Thanks to Hensel's lifting lemma, this also works in modular
        // arithmetic, doubling the correct bits in each step.
        inv *= 2 - denominator * inv; // inverse mod 2**8
        inv *= 2 - denominator * inv; // inverse mod 2**16
        inv *= 2 - denominator * inv; // inverse mod 2**32
        inv *= 2 - denominator * inv; // inverse mod 2**64
        inv *= 2 - denominator * inv; // inverse mod 2**128
        inv *= 2 - denominator * inv; // inverse mod 2**256

        // Because the division is now exact we can divide by multiplying
        // with the modular inverse of denominator. This will give us the
        // correct result modulo 2**256. Since the precoditions guarantee
        // that the outcome is less than 2**256, this is the final result.
        // We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inv;
        return result;
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
}

interface IUniswapV3Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
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

    address public poolAddress;
    address public mudAddress;
    address public signerAddress;

    mapping(uint => Delegation) public delegations;
    mapping(address => uint) public lastClaimTimestamp;
    mapping(uint => Claimant) public claimants;
    mapping(uint => uint) public undelegateIds;
    mapping(string => bool) public signatures;
    mapping(string => uint) public configs;
    mapping(address => bool) public blacklist;
    Stat public stat;

    constructor(
        address initialOwner,
        address initalSignerAddress,
        address initalPoolAddress,
        address initalMudAddress
    ) Ownable(initialOwner) {
        signerAddress = initalSignerAddress;
        poolAddress = initalPoolAddress;
        mudAddress = initalMudAddress;
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
        configs["preson_invest_min_usdt"] = 100 * 1000000;
        configs["preson_reward_min_usdt"] = 100 * 1000000;
        configs["team_reward_min_usdt"] = 1000 * 1000000;
        configs["fee"] = 0;
        configs["claim_min_usdt"] = 50 * 1000000;
        configs["team_level1_sub_usdt"] = 5000 * 1000000;
        configs["team_level1_team_usdt"] = 20000 * 1000000;
        configs["claim_max_usdt"] = 10000 * 1000000;
    }

    function mudPrice() public view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint8 decimalsMud = 6;
        uint256 numerator1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        uint256 numerator2 = 10 ** decimalsMud;
        uint256 price = ((numerator2 * numerator2) /
            FullMath.mulDiv(numerator1, numerator2, 1 << 192));

        // 收取了6个点的手续费
        return (price * 994) / 1000;
    }

    // 质押mud
    function delegate(
        uint mud,
        uint minUsdt,
        uint deadline
    ) public whenNotPaused {
        require(!blacklist[msg.sender], "You have been blacked");

        uint usdt = (mudPrice() * mud) / 1000000; // polygon中的usdt也是 6 位小数

        require(deadline >= block.timestamp, "Delegate expired");
        require(
            usdt >= minUsdt,
            "Delegate mud corresponding usdt does not meet your minimum requirement"
        );
        require(
            usdt >= configs["preson_invest_min_usdt"],
            "Delegate mud corresponding usdt does not meet system minimum requirement"
        );

        IERC20 mudToken = IERC20(mudAddress);
        bool success = mudToken.transferFrom(msg.sender, address(this), mud);
        require(success, "Token transfer failed");

        uint periodDuration = configs["period_duration"];
        uint periodNum = configs["period_num"];

        Delegation memory delegation;
        uint unlockTime = block.timestamp + periodDuration * periodNum;
        delegation.id = stat.delegateCount;
        delegation.delegator = msg.sender;
        delegation.mud = mud;
        delegation.usdt = usdt;
        delegation.unlockTime = unlockTime;
        delegation.periodDuration = periodDuration;
        delegation.periodNum = periodNum;
        delegation.withdrew = false;

        delegations[stat.delegateCount] = delegation;

        stat.delegateCount += 1;
        stat.delegateMud += mud;
        stat.delegateUsdt += usdt;

        emit Delegate(msg.sender, delegation.id, mud, usdt, unlockTime);
    }

    // 领取奖励
    // rewardIds 是用户去领取了哪些奖励id，比如 "{dynamic_ids:[1,5,6], static_ids:[1,8,9]}"
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
            block.timestamp - lastClaimTimestamp[msg.sender] >= 1 days,
            "You can claim only once per day"
        );
        require(deadline >= block.timestamp, "Claim expired");
        require(!signatures[hexSignature], "You have claimed");

        uint mud = (((usdt / mudPrice()) * (100 - configs["fee"])) / 100) *
            1000000;
        require(
            mud >= minMud,
            "Claim mud does not meet your minimum requirement"
        );

        IERC20 mudToken = IERC20(mudAddress);
        uint256 balance = mudToken.balanceOf(address(this));
        require(balance >= mud, "Insufficient balance in the contract");
        bool success = mudToken.transfer(msg.sender, mud);
        require(success, "Token transfer failed");

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

        stat.claimCount += 1;
        stat.claimMud += mud;
        stat.claimUsdt += usdt;

        emit Claim(msg.sender, claimant.id, usdt, mud, hexSignature);
    }

    // 到期重复质押
    function redelegate(uint id, uint deadline) public whenNotPaused {
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
        delegation.id = stat.delegateCount;
        delegation.delegator = msg.sender;
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

        uint mud = (delegation.usdt / mudPrice()) * 1000000;

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

        IERC20 mudToken = IERC20(mudAddress);
        uint256 balance = mudToken.balanceOf(address(this));
        require(balance >= mud, "Insufficient balance in the contract");
        bool success = mudToken.transfer(msg.sender, mud);
        require(success, "Token transfer failed");

        delegations[id].withdrew = true;
        delegations[id].backMud = mud;

        undelegateIds[stat.undelegateCount] = id;
        stat.undelegateCount += 1;
        stat.undelegateMud += mud;
        stat.undelegateUsdt += delegation.usdt;

        emit Undelegate(msg.sender, id, delegation.usdt, mud);
    }

    // 存储
    // 如果mud币价跌了，项目方则必须存入mud进行赔付
    function deposit(uint mud) public whenNotPaused {
        IERC20 mudToken = IERC20(mudAddress);
        bool success = mudToken.transferFrom(msg.sender, address(this), mud);
        require(success, "Token transfer failed");

        stat.depositMud += mud;

        emit Deposit(msg.sender, mud);
    }

    // 利润
    // 如果币价涨了，项目方可以把利润即结余的mud取出来
    function profit(uint mud) public onlyOwner whenNotPaused {
        IERC20 mudToken = IERC20(mudAddress);
        uint256 balance = mudToken.balanceOf(address(this));
        require(balance >= mud, "Insufficient balance in the contract");
        bool success = mudToken.transfer(msg.sender, mud);
        require(success, "Token transfer failed");

        stat.profitMud += mud;

        emit Profit(msg.sender, mud);
    }

    function setConfig(string memory key, uint value) public onlyOwner {
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
        uint[] memory values = new uint[](21);
        values[0] = configs["period_duration"];
        values[1] = configs["period_num"];
        values[2] = configs["period_reward_ratio"];
        values[3] = configs["person_reward_level1"];
        values[4] = configs["person_reward_level2"];
        values[5] = configs["person_reward_level3"];
        values[6] = configs["person_reward_level4"];
        values[7] = configs["person_reward_level5"];
        values[8] = configs["team_reward_level1"];
        values[9] = configs["team_reward_level2"];
        values[10] = configs["team_reward_level3"];
        values[11] = configs["team_reward_level4"];
        values[12] = configs["team_reward_level5"];
        values[13] = configs["preson_invest_min_usdt"];
        values[14] = configs["preson_reward_min_usdt"];
        values[15] = configs["team_reward_min_usdt"];
        values[16] = configs["fee"];
        values[17] = configs["claim_min_usdt"];
        values[18] = configs["team_level1_sub_usdt"];
        values[19] = configs["team_level1_team_usdt"];
        values[20] = configs["claim_max_usdt"];

        return values;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function addBlackList(address user, bool isBlack) public onlyOwner {
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
        // 检查签名长度，65是标准r,s,v签名的长度
        require(sig.length == 65, "invalid signature length");

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 0x20))
            // second 32 bytes
            s := mload(add(sig, 0x40))
            // final byte (first byte of the next 32 bytes)
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
}
