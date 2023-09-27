# Circuit Resolver Module

See [ICircuitResolverModule.sol](/solidity/interfaces/modules/dispute/ICircuitResolverModule.sol/interface.ICircuitResolverModule.md) for more details.

## 1. Introduction

The Circuit Resolver Module is a pre-dispute module that allows disputers to verify a zero-knowledge circuit for a given request and propose it as a response, starting and resolving the dispute atomically.

## 2. Contract Details

### Key Methods

- `decodeRequestData(bytes32 _requestId)`: Returns the decoded data for a request.
- `disputeResponse(bytes32 _requestId, bytes32 _responseId, address _disputer, address _proposer)`: Verifies the ZK circuit and compares it to the proposed one. Updates the dispute status after checking if the disputed response is indeed wrong.
- `onDisputeStatusChange(bytes32 _requestId, IOracle.Dispute memory _dispute)`: Updates the status of the dispute and resolves it by proposing the correct circuit as a response and finalizing the request.
- `disputeEscalated(bytes32 _disputeId)`: This function is present to comply with the module interface but it is not implemented since this is a pre-dispute module.

### Request Parameters

- `callData`: The encoded data forwarded to the verifier.
- `verifier`: The address of the verifier contract.
- `accountingExtension`: The accounting extension to use for payments.
- `bondToken`: The token to use for payments, it must be the same token that was specified for the response module.
- `bondSize`: The size of the payment for winning a dispute, it must be the same amount that was specified for the response module.

## 3. Key Mechanisms & Concepts

- Verifier: A contract implementing the verification logic, which will be consulted in case of a dispute.
- Atomical dispute: With this module, a dispute is initiated and resolved in the same transaction because the answer can be (somewhat expensively) calculated on-chain.

## 4. Gotchas

- The disputer is not required to bond any tokens in order to start a dispute, because in case they're wrong the cost of calculating the answer will be the penalty. However, depending on the chosen response module, they might be required to bond as a proposer of a new response.
- The module relies on the correct implementation of the verifier. If the verifier's logic if flawed, the module may not be able to resolve disputes correctly.
