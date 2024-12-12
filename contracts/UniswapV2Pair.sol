// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

contract UniswapV2Pair {
    address public token0;
    address public token1;

    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    uint112 private reserve1; // uses single storage slot, accessible via getReserves

    constructor() {
        token0 = 0x592d157a0765b43b0192Ba28F4b8cd4F50E326cF;
        token1 = 0x82f9d23cB62Ec0016109B7C4b8dB34890FdBA0F0;
        reserve0 = 9999990120181;
        reserve1 = 500000507496024002460996;
    }

    function setReserve(uint112 reserve0_, uint112 reserve1_) public {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, uint32(block.timestamp));
    }
}
