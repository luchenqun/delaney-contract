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
        uint256 mud,
        uint256 usdt,
        uint256 unlockTime
    );

    event Claim(
        address indexed delegator,
        uint256 usdt,
        uint256 mud,
        string reward
    );

    event Withdraw(address indexed delegator, uint256 usdt, uint256 mud);

    struct Delegation {
        uint id;
        address delegator;
        uint mud; // 每次质押数量
        uint usdt; // 数量对应usdt的价值
        uint unlockTime; // 解锁时间
        bool withdrawn;
    }

    address public poolAddress;
    address public mudAddress;
    address public signerAddress;
    uint public periodDuration = 15 * 24 * 3600; // 15 day
    uint public periodNum = 8;
    uint public minPersonInvestUsdt = 100000000; // 100usdt
    uint public fee = 1; // 1%的手续费
    uint public totalDelegate = 0; //

    mapping(uint => Delegation) public delegations;
    mapping(address => uint) lastClaimTimestamp;

    constructor(
        address initialOwner,
        address initalPoolAddress,
        address initalMudAddress,
        address initalSignerAddress
    ) Ownable(initialOwner) {
        poolAddress = initalPoolAddress;
        mudAddress = initalMudAddress;
        signerAddress = initalSignerAddress;
    }

    //function to get the public address of the signer
    function recoverSignerFromSignature(
        bytes32 message,
        bytes memory signature
    ) internal pure returns (address) {
        require(signature.length == 65);

        uint8 v;
        bytes32 r;
        bytes32 s;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(signature, 32))
            // second 32 bytes
            s := mload(add(signature, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(signature, 96)))
        }

        return ecrecover(message, v, r, s);
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
        uint usdtMin,
        uint deadline
    ) public whenNotPaused {
        uint usdt = mudPrice() * mud; // polygon中的usdt也是 6 位小数

        require(deadline >= block.timestamp, "Delegate expired");
        require(
            usdt >= usdtMin,
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
        delegation.id = totalDelegate;
        delegation.delegator = msg.sender;
        delegation.mud = mud;
        delegation.usdt = usdt;
        delegation.unlockTime = unlockTime;
        delegation.withdrawn = false;
        delegations[totalDelegate] = delegation;

        totalDelegate += 1;

        emit Delegate(msg.sender, mud, usdt, unlockTime);
    }

    // 领取奖励
    // reward 是用户去领取了哪些奖励id，比如 "{dynamic:[1,5,6], static:[1,8,9]}"
    function claim(
        uint usdt,
        uint mudMin,
        string memory claimIds,
        bytes memory signature,
        uint deadline
    ) public whenNotPaused {
        uint mud = ((usdt / mudPrice()) * (100 - fee)) / 100;
        // TODO
        address signer = recoverSignerFromSignature(
            bytes32(uint256(140714483853992465185976883)),
            signature
        );

        require(
            signer == signerAddress,
            "Administrator signature is required for claim"
        );
        require(
            block.timestamp - lastClaimTimestamp[msg.sender] >= 1 days,
            "You can claim only once per day"
        );
        require(deadline >= block.timestamp, "Claim expired");
        require(
            mud >= mudMin,
            "Claim mud does not meet your minimum requirement"
        );

        IERC20 mudToken = IERC20(mudAddress);
        uint256 balance = mudToken.balanceOf(address(this));
        require(balance >= mud, "Insufficient balance in the contract");
        bool success = mudToken.transfer(msg.sender, mud);
        require(success, "Token transfer failed");

        emit Claim(msg.sender, usdt, mud, claimIds);
    }

    // 结束质押
    function withdraw(
        uint delegateId,
        uint mudMin,
        uint deadline
    ) public whenNotPaused {
        Delegation memory delegation = delegations[delegateId];
        uint mud = delegation.usdt / mudPrice();

        require(deadline >= block.timestamp, "Withdraw expired");
        require(
            block.timestamp > delegation.unlockTime,
            "You can't withdraw yet"
        );
        require(delegation.delegator == msg.sender, "You aren't the delegator");
        require(
            mud >= mudMin,
            "Withdraw mud does not meet your minimum requirement"
        );

        IERC20 mudToken = IERC20(mudAddress);
        uint256 balance = mudToken.balanceOf(address(this));
        require(balance >= mud, "Insufficient balance in the contract");
        bool success = mudToken.transfer(msg.sender, mud);
        require(success, "Token transfer failed");

        emit Withdraw(msg.sender, delegation.usdt, mud);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
