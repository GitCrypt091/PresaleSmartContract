const web3 = require('web3');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const TokenPreSale = artifacts.require("TokenPreSale");
var TestUSDT = artifacts.require("TestUSDT");
var TestErc20Token = artifacts.require("TestErc20Token");

module.exports = async function (deployer) {
  // BSC Testnet
  // Bsc Testnet BNB / USD Oracle: 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526 -> https://docs.chain.link/docs/data-feeds/price-feeds/addresses/
  // TestUSDT BscTestNet (created with TestUSDT contract) = 0x250df3426Facabb1a1AE0145ea2E86cdbb296fA7
  // 
  // Goerli ETH Testnet
  // Goerli ETH/USDT Oracle: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e -> https://docs.chain.link/docs/data-feeds/price-feeds/addresses/
  // TestUSDT Goerli (created with TestUSDT contract) = 0x2BDc3A5CC1DFB531d6eB77812D08bD8C7201c683

  // Deploy Presale Contract
  const presaleInstance = await deployer.deploy(TokenPreSale, ['0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526', '0x250df3426Facabb1a1AE0145ea2E86cdbb296fA7']);
  console.log('Deployed', presaleInstance.address);

  // Initiate Presale
  await presaleInstance.createPresale(1668360000, 1680328800, BigInt(18005041411595246), 10000000, BigInt(1000000000000000000), 1680328801, 0, 0, 0, 1)
  // add me to Presale
  await presaleInstance.addToWhitelist(1, [0x524e4444e4A38D00Dde292a3a121a5129e1f03aB])
  // Deploy USDT
  const USDTInstance = await deployer.deploy(TestUSDT);
  // Approve USDT
  await USDTInstance.approve(presaleInstance.address, '9999999999999999999999999999999999999999999999')
  // Deploy Mock Token
  const MockInstance = await deployer.deploy(TestErc20Token);
  // Transfer all Mock Tokens to Presale Contract
  await MockInstance.transfer(presaleInstance.address, '1000000000000000000000000000')
  // Buy with USDT, 100 tokens
  await presaleInstance.buyWithUSDT('1', '100000000000000000000')
  // Buy with ETH, 1 token
  await presaleInstance.buyWithEth('1','1000000000000000000')
  // check how much I can claim
  const claimableAmount = await presaleInstance.claimableAmount('0x524e4444e4A38D00Dde292a3a121a5129e1f03aB', "1");
  console.log("I can claim: ", claimableAmount, " Tokens")
  // claim my tokens
  await presaleInstance.claim('0x524e4444e4A38D00Dde292a3a121a5129e1f03aB','1')
  // finalize presale
  await presaleInstance.finalizeAndAddLiquidity('1')
  



};
