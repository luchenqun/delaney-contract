# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
npx hardhat verify --network mud 0xda2830331B3dE0B5Dd2E4EbdF981f18d5c47018c 0x00000004e1E16f249E2b71c2dc66545215FE9d84 0x00000004e1E16f249E2b71c2dc66545215FE9d84 0x60D8A47c075E7E95cd58C7C5598208F58c89242C 0x9922308f2d9202C0650347d06Cb2095F3dD234BE  --contract contracts/Delaney.sol:Delaney --show-stack-traces 
```
