// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetaUserDAOToken is ERC20, Ownable {
    constructor(
        address initialOwner
    ) ERC20("MetaUserDAO", "MUD") Ownable(initialOwner) {
        _mint(msg.sender, 10000000000000);
        _mint(0x00000Be6819f41400225702D32d3dd23663Dd690, 1000000000000);
        _mint(0x1111102Dd32160B064F2A512CDEf74bFdB6a9F96, 1000000000000);
        _mint(0x2222207B1f7b8d37566D9A2778732451dbfbC5d0, 1000000000000);
        _mint(0x00000Be6819f41400225702D32d3dd23663Dd690, 1000000000000);
        _mint(0x33333BFfC67Dd05A5644b02897AC245BAEd69040, 1000000000000);
        _mint(0x4444434e38E74c3e692704e4Ba275DAe810B6392, 1000000000000);
        _mint(0x55555d6c72886E5500a9410Ca15D08A16011ed95, 1000000000000);
        _mint(0x666668F2a2E38e93089B6e6A2e37C854bb6dB7de, 1000000000000);
        _mint(0x77777295eEe9B2b4Da75Ac0F2d3B14B20B5883Da, 1000000000000);
        _mint(0x99C428241b66F1cDBCd33FD7A7c276ae42A09e03, 1000000000000);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
