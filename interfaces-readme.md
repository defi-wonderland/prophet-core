# Optimistic Oracle Interfaces

This package includes all of the needed resources in order to integrate OpOO into your scripts, UI, or smart-contracts:

- Interfaces ABIs
- Interfaces solidity code
- Typesafe interfaces for Ethers generated with [@typechain/ethers-v5](https://www.npmjs.com/package/@typechain/ethers-v5)
- Typesafe interfaces for Truffle generated with [@typechain/truffle-v5](https://www.npmjs.com/package/@typechain/truffle-v5)
- Typesafe interfaces for Web3 generated with [@typechain/web3-v1](https://www.npmjs.com/package/@typechain/web3-v1)

## Installation

You can install this package via npm or yarn:

```console
yarn add @opoo/interfaces
```

```console
npm install @opoo/interfaces
```

## Licensing

The primary license for Optimistic Oracle Interfaces is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE.BSL-1.1`](./LICENSE.BSL-1.1). However, some files are dual licensed under `AGPL-3.0-only`:

- All files in `contracts` may also be licensed under `AGPL-3.0-only` (as indicated in their SPDX headers), see [`LICENSE.AGPL-3.0`](./LICENSE.AGPL-3.0)
- All files in `abi`, `ethers-v5`, and `web3-v1` are licensed under `MIT`, see [`LICENSE.MIT`](./LICENSE.MIT)
