# MerkleLib

## 1. Introduction

The `MerkleLib` is a Solidity library that provides functionality for managing an incremental Merkle tree. The library includes functions for inserting nodes into the tree and calculating the root of the tree.

The library is a part of the [Connext monorepo](https://github.com/connext/monorepo/blob/main/packages/deployments/contracts/contracts/messaging/libraries/MerkleLib.sol).

## 2. Contract Details

### Key Methods

- `insert(Tree memory tree, bytes32 node)`: This function inserts a given node (leaf) into the Merkle tree. It operates on an in-memory tree and returns an updated version of that tree. If the tree is already full, it reverts the transaction.

## 3. Key Mechanisms & Concepts

The `MerkleLib` uses a struct `Tree` to represent the Merkle tree. This struct contains the current branch of the tree and the number of inserted leaves in the tree.

The library also defines a set of constants `Z_i` that represent the hash values at different heights for a binary tree with leaf values equal to 0. These constants are used to shortcut calculation in root calculation functions.
