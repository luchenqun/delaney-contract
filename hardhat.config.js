require('@nomicfoundation/hardhat-toolbox');
require('@nomicfoundation/hardhat-verify');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: '0.8.27',
  networks: {
    hardhat: {
      accounts: [
        { privateKey: 'f78a036930ce63791ea6ea20072986d8c3f16a6811f6a2583b0787c45086f769', balance: '100000000000000000000000' },
        { privateKey: '95e06fa1a8411d7f6693f486f0f450b122c58feadbcee43fbd02e13da59395d5', balance: '100000000000000000000000' },
        { privateKey: '322673135bc119c82300450aed4f29373c06926f02a03f15d31cac3db1ee7716', balance: '100000000000000000000000' },
        { privateKey: '09100ba7616fcd062a5e507ead94c0269ab32f1a46fe0ec80056188976020f71', balance: '100000000000000000000000' },
        { privateKey: '5352cfb603f3755c71250f24aa1291e85dbc73a01e9c91e7568cd081b0be04db', balance: '100000000000000000000000' },
        { privateKey: 'f3d9247d078302fd876462e2036e05a35af8ca6124ba1a8fd82fc3ae89b2959d', balance: '100000000000000000000000' },
        { privateKey: '39cfe0662cdede90094bf079b339e09e316b1cfe02e92d56a4d6d95586378e38', balance: '100000000000000000000000' },
        { privateKey: 'a78e6fe4fe2c66a594fdd639b39bd0064d7cefbbebf43b57de153392b0f4e30c', balance: '100000000000000000000000' },
      ],
      mining: {
        auto: true,
        // Produce new block every 3 minutes to resolve next issues
        // https://github.com/NomicFoundation/hardhat/issues/2053
        // https://github.com/ethers-io/ethers.js/issues/2338
        // https://github.com/ethers-io/ethers.js/discussions/4116
        interval: 3 * 60 * 1000, // should be less then 5 minutes to make event subscription work
      },
    },
    mud: {
      url: 'https://testnet-rpc.mud-chain.net',
      accounts: ['f78a036930ce63791ea6ea20072986d8c3f16a6811f6a2583b0787c45086f769'],
    },
  },
  etherscan: {
    apiKey: {
      mud: 'It seems like you can write whatever you want',
    },
    customChains: [
      {
        network: 'mud',
        chainId: 168169,
        urls: {
          apiURL: 'https://testnet-scan.mud-chain.net/api',
          browserURL: 'https://testnet-scan.mud-chain.net/',
        },
      },
    ],
  },
  sourcify: {
    enabled: false,
  },
};
