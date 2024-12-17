# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
npx hardhat verify --network mud 0xEfcc761e11b5F28DDdD45c3B2CC36fAB139e98FE 0x00000004e1E16f249E2b71c2dc66545215FE9d84 0x00000004e1E16f249E2b71c2dc66545215FE9d84 0x7F202fda32D43F726C77E2B3288e6c6f3e7e341A 0x592d157a0765b43b0192Ba28F4b8cd4F50E326cF  --contract contracts/Delaney.sol:Delaney --show-stack-traces 
```
