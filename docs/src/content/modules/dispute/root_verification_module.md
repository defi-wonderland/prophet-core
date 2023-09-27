# Root Verification Module

See [IRootVerificationModule.sol](/solidity/interfaces/modules/dispute/IRootVerificationModule.sol/interface.IRootVerificationModule.md) for more details.

## 1. Introduction

The Root Verification Module is a pre-dispute module that allows disputers to calculate the correct Merkle root for a given request and propose it as a response, starting and resolving the dispute atomically.

## 2. Contract Details

### Key Methods

- `decodeRequestData(bytes32 _requestId)`: Returns the decoded data for a request.
- `disputeResponse(bytes32 _requestId, bytes32 _responseId, address _disputer, address _proposer)`: Calculates the correct root and compares it to the proposed one. Updates the dispute status after checking if the disputed response is indeed wrong.
- `onDisputeStatusChange(bytes32 _requestId, IOracle.Dispute memory _dispute)`: Updates the status of the dispute and resolves it by proposing the correct root as a response and finalizing the request.
- `disputeEscalated(bytes32 _disputeId)`: This function is present to comply with the module interface but it is not implemented since this is a pre-dispute module.

### Request Parameters

- `treeData`: The Merkle tree.
- `leavesToInsert`: The leaves to insert in the tree.
- `treeVerifier`: The tree verifier to use to calculate the correct root.
- `accountingExtension`: The accounting extension to use for payments.
- `bondToken`: The token to use for payments, it must be the same token that was specified for the response module.
- `bondSize`: The size of the payment for winning a dispute, it must be the same amount that was specified for the response module.

## 3. Key Mechanisms & Concepts

- Tree verifier: A contract implementing the `ITreeVerifier` interface, which will be consulted in case of a dispute and will provide the correct root for the Merkle tree, taking into consideration the new leaves.
- Atomical dispute: With this module, a dispute is initiated and resolved in the same transaction because the answer can be (somewhat expensively) calculated on-chain.

## 4. Gotchas

- The module is supposed to be paired with the sparse merkle tree module or a similar one.
- The disputer is not required to bond any tokens in order to start a dispute, because in case they're wrong the cost of calculating the correct root will be the penalty. However, depending on the chosen response module, they might be required to bond as a proposer of a new response.
- The module relies on the correct implementation of the tree verifier to calculate the Merkle root. If the tree verifier's logic if flawed, the module may not be able to resolve disputes correctly.
