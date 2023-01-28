const web3 = require('web3');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const TokenPreSale = artifacts.require("TokenPreSale");
var TestErc20Token = artifacts.require("TestErc20Token");

module.exports = async function (deployer) {
  // BSC Testnet
  // Bsc Testnet BNB / USD Oracle: 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526 -> https://docs.chain.link/docs/data-feeds/price-feeds/addresses/
  // TestUSDT BscTestNet (created with TestUSDT contract) = 0x250df3426Facabb1a1AE0145ea2E86cdbb296fA7
  // 
  // Goerli ETH Testnet
  // Goerli WETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6
  // Goerli Uni Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D 
  // Goerli ETH/USDT Oracle: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e -> https://docs.chain.link/docs/data-feeds/price-feeds/addresses/
  // TestUSDT Goerli (created with TestUSDT contract) = 0x2BDc3A5CC1DFB531d6eB77812D08bD8C7201c683

  const goerliWETH = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6"
  const goerliRouter = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D" 

  const bscWETH = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"
  const bscRouter = "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3"


  // Deploy Presale Contract
  const presaleInstance = await deployProxy(TokenPreSale, ['0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e', bscWETH, bscRouter], { deployer });
  console.log('Deployed', presaleInstance.address);

  // Initiate Presale
  await presaleInstance.createPresale(10, 1000000, 1000000, 18, 0, 0, 20, false, ['0x524e4444e4A38D00Dde292a3a121a5129e1f03aB'])
  await presaleInstance.addSaleTimes(1, 1674925807, 1674936607, 1674925807, 1674936607, 1674936607)
  // add me to Presale
  await presaleInstance.addToWhitelist(1, [0x524e4444e4A38D00Dde292a3a121a5129e1f03aB])
  
  /*
  
  // Deploy Mock Token
  const MockInstance = await deployer.deploy(TestErc20Token);
  // Transfer all Mock Tokens to Presale Contract
  await MockInstance.transfer(presaleInstance.address, '1000000000000000000000000000')
  // Buy with ETH, 1 token
  await presaleInstance.buyWithEth('1','1000000000000000000')
  // check how much I can claim
  const claimableAmount = await presaleInstance.claimableAmount('0x524e4444e4A38D00Dde292a3a121a5129e1f03aB', "1");
  console.log("I can claim: ", claimableAmount, " Tokens")
  // claim my tokens
  await presaleInstance.claim('0x524e4444e4A38D00Dde292a3a121a5129e1f03aB','1')
  // finalize presale
  await presaleInstance.finalizeAndAddLiquidity('1')
  */
  



};
