const web3 = require('web3');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const TokenPreSale = artifacts.require("TokenPreSale");
var TestErc20Token = artifacts.require("TestErc20Token");
const delay = ms => new Promise(resolve => setTimeout(resolve, ms))
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


    // truffle run verify TokenPreSale --network development [--debug] [--verifiers=etherscan,sourcify]
    // truffle run verify TokenPreSale@0xf46E8b47C4009a3DCbBe3De6E0830C0573B6c3Cb --network bscTestNet

    // Ganache Dev: 0x0760be9FE84519132FA54D74dd445B79F85AFD13
  const goerliWETH = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6"
  const goerliRouter = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D" 

  const bscWETH = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"
  const bscRouter = "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3"


  // Deploy Presale Contract
  await deployer.deploy(TokenPreSale, bscRouter)
  const presaleInstance = await TokenPreSale.deployed()


  console.log('Deployed', presaleInstance.address);

  // Initiate Presale
  const _price = "100000000000000"
  const _tokensToSell = "500000000000000000000000"
  const _maxAmountTokensForSalePerUser = "500000000000000000000000"
  const _amountTokensForLiquidity = "500000000000000000000000"
  const _baseDecimals = "18"
  const _inSale = _tokensToSell
  const _vestingCliff = 0
  const _vestingPeriod = 0
  const _marketingPercentage = 20
  const _presaleFinalized = false
  const _whitelist = ['0x524e4444e4A38D00Dde292a3a121a5129e1f03aB']

  await presaleInstance.createPresale(_price, _tokensToSell, _maxAmountTokensForSalePerUser, _amountTokensForLiquidity, _baseDecimals, _inSale, _vestingCliff, _vestingPeriod, _marketingPercentage, _presaleFinalized, _whitelist)

  console.log("adding time")
  // Add Time
  const _startTimePhase1 = "1675016678"
  const _endTimePhase1  = "1677686087"
  const _startTimePhase2  = "1675016678"
  const _endTimePhase2  = "1677686087"
  const _vestingStartTime  = _endTimePhase2

  await presaleInstance.addSaleTimes(1, _startTimePhase1, _endTimePhase1, _startTimePhase2, _endTimePhase2, _vestingStartTime)
  // add me to Presale
  await presaleInstance.addToWhitelist(1, ['0x57b1fF270fEd868f819191fc72f10D6403441447', '0x018910538C95459457eAFf266cD25c45618c2A9f'])

  // Deploy Mock Token
  console.log("deploying mock token")
  const MockInstance = await deployer.deploy(TestErc20Token);
  const MockContract = await TestErc20Token.deployed()
  // Transfer all Mock Tokens to Presale Contract
  console.log("transfering tokens")
  await MockInstance.transfer(presaleInstance.address, '1000000000000000000000000')
  console.log("adding new address")
  console.log(MockContract.address)
  // set Token Contract in Sale
  await presaleInstance.changeSaleTokenAddress(1, MockContract.address)
  console.log("waiting 5min")
  await delay(300000)
  
   // Buy with ETH, 1 token
   console.log("buying tokens")
   //await presaleInstance.buyWithEth('1','1')
   await presaleInstance.buyWithEth('1', '1', {value: '100000000000000', from: '0x524e4444e4A38D00Dde292a3a121a5129e1f03aB'});
   console.log("finalizing presale")
   // finalize presale
  await presaleInstance.finalizeLiquidity('1')

  console.log("claiming marketingfunds")
   // finalize presale
  await presaleInstance.finalizePresale('1')


  /*
  let instance6 = await new web3.eth.Contract(TokenPreSale.abi, "0xbc95ba9517f97d86424cdcb97de12e2900661aa7")
  instance5.methods.buyWithEth('1','1').send({from: '0x708454670F964754e7A207929a0A07b51c7ae4b2', value: '1000000000000000' })
  instance6.methods.finalizeAndAddLiquidity('1').send({from: '0x524e4444e4A38D00Dde292a3a121a5129e1f03aB', value: '0' })
  TokenPreSale.deployed().then(function(instance){ return instance.buyWithEth('1','1', {from: '0x524e4444e4A38D00Dde292a3a121a5129e1f03aB', value: '10000000000000000' }); })
  */

  /*

 

  // check how much I can claim
  const claimableAmount = await presaleInstance.claimableAmount('0x524e4444e4A38D00Dde292a3a121a5129e1f03aB', "1");
  console.log("I can claim: ", claimableAmount, " Tokens")

  
  
  
  // claim my tokens
  await presaleInstance.claim('0x524e4444e4A38D00Dde292a3a121a5129e1f03aB','1')
  
  */
  



};
