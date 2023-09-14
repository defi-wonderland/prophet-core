# Bonded Dispute Module

## 1. Introduction

The Bonded Dispute Module is a contract that allows users to dispute a proposed response by bonding tokens. Depending on the result of the dispute, the tokens are either returned to the disputer or to the proposer (slashed).

## 2. Contract Details

### Key Methods:

- `decodeRequestData(bytes32 _requestId)`: Returns the decoded data for a request.
- `disputeResponse(bytes32 _requestId, bytes32 _responseId, address _disputer, address _proposer)`: Starts a dispute.
- `onDisputeStatusChange(bytes32 _disputeId, IOracle.Dispute memory _dispute)`: Is a hook called by the oracle when a dispute status has been updated.
- `disputeEscalated(bytes32 _disputeId)`: Called by the oracle when a dispute has been escalated. Not implemented in this module.

### Request Parameters

- `_accountingExtension`: The address holding the bonded tokens. It must implement the `IAccountingExtension` interface.
- `_bondToken`: The ERC20 token used for bonding.
- `_bondSize`: The amount of tokens the disputer must bond to be able to dispute a response.

## 3. Key Mechanisms & Concepts

Check out [Accounting Extension](../../extensions/accounting.md).

## 4. Gotchas

- The module does not handle the cases of inconclusive dispute, e.g. if a ERC20 vote has failed to reach the quorum.

## 5. Failure Modes

- Choosing a non-ERC20 token might result in disputers not being able to use this module.
