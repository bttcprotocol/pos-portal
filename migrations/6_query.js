const ChildChainManager = artifacts.require('ChildChainManager')

const utils = require('./utils')

const ChildERC20 = artifacts.require('UChildERC20')

module.exports = async(deployer, network, accounts) => {

  //await deployer.deploy(ChildERC20)

  const contractAddresses = utils.getContractAddresses()

  const ChildChainManagerInstance = await ChildChainManager.at(contractAddresses.child.ChildChainManagerProxy)

  console.log('Granting STATE_SYNCER_ROLE on ChildChainManager')
  const STATE_SYNCER_ROLE = await ChildChainManagerInstance.STATE_SYNCER_ROLE()
  const owner = await ChildChainManagerInstance.getRoleMember(STATE_SYNCER_ROLE, 0)
  const owner1 = await ChildChainManagerInstance.getRoleMember(STATE_SYNCER_ROLE, 1)

  console.log('owner')
  console.log(owner)
  console.log(owner1)

  const rootToken = await ChildChainManagerInstance.childToRootToken('0x0000000000000000000000000000000000001010')
  console.log('roottoken')
  console.log(rootToken)

  const dummyRootToken = await ChildChainManagerInstance.childToRootToken('0xa9C774B96bcd0c056B46ee4c31F75Ca1F68eb8B3')
  console.log('dummyRootToken')
  console.log(dummyRootToken)

  const dummyRootToken1 = await ChildChainManagerInstance.rootToChildToken('0x6DA52943065C6B8B54D4023CC8583CE74B0D01E6')
  console.log('dummyRootToken1')
  console.log(dummyRootToken1)

  const mintableDummyRootToken = await ChildChainManagerInstance.childToRootToken('0x8f4fCC69cC96c6629c86D164C440858D4A9c350D')
  console.log('mintable')
  console.log(mintableDummyRootToken)

  const mintableErc20RootToken = await ChildChainManagerInstance.childToRootToken('0x11471001470260aaefA275eAE78B85315eD2a129')
  console.log('mintableErc20')
  console.log(mintableErc20RootToken)

}
