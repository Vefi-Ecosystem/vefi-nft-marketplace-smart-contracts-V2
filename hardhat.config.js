require('@nomiclabs/hardhat-ganache');
require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-truffle5');
require('@nomiclabs/hardhat-etherscan');

require('dotenv').config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 6000000,
      },
      viaIR: true,
    },
  },
  networks: {
    bsc_testnet: {
      url: 'https://bsctestapi.terminet.io/rpc',
      accounts: [process.env.PRIVATE_KEY],
      chainId: 97,
    },
  },
  etherscan: {
    apiKey: {
      bscTestnet: process.env.BSC_API_KEY,
      bsc: process.env.BSC_API_KEY,
    },
  },
};
