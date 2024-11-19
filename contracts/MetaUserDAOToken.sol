// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetaUserDAOToken is ERC20, Ownable {
    constructor(
        address initialOwner
    ) ERC20("MetaUserDAO", "MUD") Ownable(initialOwner) {
        _mint(msg.sender, 977061247291058);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
