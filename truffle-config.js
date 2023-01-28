/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 * 
 * https://trufflesuite.com/docs/truffle/reference/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

 require('dotenv').config();

const HDWalletProvider = require('@truffle/hdwallet-provider');
const fs = require('fs');

module.exports = {
  plugins: [
    'truffle-plugin-verify'
  ],

  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard BSC port (default: none)
      network_id: "*",       // Any network (default: none)
    },
    bscTestNet: {
      provider: () => new HDWalletProvider(process.env.WALLET_PRIVATE_KEY, `https://data-seed-prebsc-2-s3.binance.org:8545`),
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true,
      stackSize: 18192,
      networkCheckTimeout: 10000
    },
    bsc: {
      provider: () => new HDWalletProvider(process.env.WALLET_PRIVATE_KEY, `https://bsc-dataseed1.binance.org`),
      network_id: 56,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true,
      stackSize: 18192
    },
    goerli: {
      provider: () => new HDWalletProvider(process.env.WALLET_PRIVATE_KEY, 'https://rpc.ankr.com/eth_goerli'),
      network_id: '5',
      networkCheckTimeout: 10000,
      timeoutBlocks: 200,
      stackSize: 18192,
      networkCheckTimeout: 10000
    }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },
  optimizer: {
    enabled: true,
    runs: 200,
    viaIR: true
  },

  

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.17",      // Fetch exact version from solc-bin (default: truffle's version)
    }
  },
};
