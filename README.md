# Bttc PoS (Proof-of-Stake) portal contracts

Smart contracts that powers the PoS (proof-of-stake) based bridge mechanism for Bttc Network. 
A cross-chain bridge based on pos consensus, which has both security and ease of use.

### Core Contracts

- `RootChainManager`: Responsible for the logic of deposit and withdraw
- `ChildChainManager`: Responsible map token between mainnet and childnet, also mint the token on child chain when token locked on mainnet
- `ERC20Predicate`: the tokens that user deposit will be locked in the proxy of this contract
- `MintableERC20Predicate`: like `ERC20Predicate`, also responsible for mint token on mainnet for the token which can be minted on child chain
- `DummyERC20`: template for ERC20 token in mainnet
- `ChildERC20`: template for ERC20 token in childnet

### Dependency

- require node version: v11

### Install dependencies with

```
npm install
```

### Compile

```
npm run truffle:compile
```

### Flat contracts

```
node scripts/flatten-contracts.js
```