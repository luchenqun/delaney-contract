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
        uint minMud;
        uint usdt;
        string rewardIds;
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

    address constant ZeroAddress = address(0);

    address public poolAddress;
    address public mudAddress;
    address public signerAddress;
    uint public periodDuration = 15 * 24 * 3600; // 15 day
    uint public periodNum = 8;
    uint public minPersonInvestUsdt = 100000000; // 100usdt
    uint public fee = 1; // 1%的手续费

    mapping(uint => Delegation) public delegations;
    mapping(address => uint) lastClaimTimestamp;
    mapping(uint => Claimant) public claimants;
    mapping(uint => uint) public undelegateIds;
    mapping(string => bool) public signatures;
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
        uint usdt = (mudPrice() * mud) / 1000000; // polygon中的usdt也是 6 位小数

        require(deadline >= block.timestamp, "Delegate expired");
        require(
            usdt >= minUsdt,
            "Delegate mud corresponding usdt does not meet your minimum requirement"
        );
        require(
            usdt >= minPersonInvestUsdt,
            "Delegate mud corresponding usdt does not meet system minimum requirement"
        );

        IERC20 mudToken = IERC20(mudAddress);
        bool success = mudToken.transferFrom(msg.sender, address(this), mud);
        require(success, "Token transfer failed");

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
    // rewardIds 是用户去领取了哪些奖励id，比如 "{dynamic:[1,5,6], static:[1,8,9]}"
    function claim(
        uint usdt,
        uint minMud,
        string memory rewardIds,
        bytes memory signature,
        uint deadline
    ) public whenNotPaused {
        // string memory packedData = string(
        //     abi.encodePacked(msg.sender, usdt, minMud, rewardIds, deadline)
        // );
        // bool verify = verifySign(signerAddress, packedData, signature);
        // require(verify, "Administrator signature is required for claim");
        string memory sign = string(signature);

        require(
            block.timestamp - lastClaimTimestamp[msg.sender] >= 1 days,
            "You can claim only once per day"
        );
        require(deadline >= block.timestamp, "Claim expired");
        require(!signatures[sign], "You have claimed");

        uint mud = ((usdt / mudPrice()) * (100 - fee)) / 100;
        // require(
        //     mud >= minMud,
        //     "Claim mud does not meet your minimum requirement"
        // );

        IERC20 mudToken = IERC20(mudAddress);
        uint256 balance = mudToken.balanceOf(address(this));
        require(balance >= mud, "Insufficient balance in the contract");
        bool success = mudToken.transfer(msg.sender, mud);
        require(success, "Token transfer failed");

        Claimant memory claimant;
        claimant.id = stat.claimCount;
        claimant.delegator = msg.sender;
        claimant.minMud = minMud;
        claimant.usdt = usdt;
        claimant.rewardIds = rewardIds;
        claimant.deadline = deadline;
        claimants[stat.claimCount] = claimant;

        signatures[sign] = true;

        stat.claimCount += 1;
        stat.claimMud += mud;
        stat.claimUsdt += usdt;

        emit Claim(msg.sender, claimant.id, usdt, mud, sign);
    }

    // 到期重复质押
    function redelegate(uint id, uint deadline) public whenNotPaused {
        Delegation memory delegation = delegations[id];

        require(delegation.delegator == msg.sender, "You aren't the delegator");
        require(!delegation.withdrew, "You have withdrew");
        require(deadline >= block.timestamp, "Redelegate expired");
        require(
            block.timestamp > delegation.unlockTime,
            "You can't redelegate yet"
        );

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
        Delegation memory delegation = delegations[id];
        require(delegation.delegator == msg.sender, "You aren't the delegator");

        uint mud = delegation.usdt / mudPrice();

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
        delegations[id].backMud = balance;

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
        uint256 balance = mudToken.balanceOf(address(this));
        require(balance >= mud, "Insufficient balance in the contract");
        bool success = mudToken.transfer(msg.sender, mud);
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

    function setPeriodDuration(uint _periodDuration) public onlyOwner {
        periodDuration = _periodDuration;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // 验证签名
    // 管理员进行对原始数据签名，通过此方法验证是否为管理员签名
    function verifySign(
        address signer,
        string memory data,
        bytes memory signature
    ) internal pure returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(data));

        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n", messageHash)
        );
        //function to get the public address of the signer
        (bytes32 r, bytes32 s, uint8 v) = splitSign(signature);
        address recoveredSigner = ecrecover(ethSignedMessageHash, v, r, s);

        return (recoveredSigner == signer);
    }

    function splitSign(
        bytes memory sig
    ) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := and(mload(add(sig, 96)), 0xff)
        }

        if (v < 27) {
            v += 27;
        }
    }
}
