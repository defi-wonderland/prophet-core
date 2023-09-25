# Arbitrator Module

## 1. Introduction

The Arbitrator Module is a part of the dispute resolution system. It allows an external arbitrator contract to resolve a dispute. The module provides methods to start the arbitration process, resolve the dispute, and get the status and validity of a dispute.

## 2. Contract Details

### Key Methods:

- `getStatus(bytes32 _disputeId)`: Returns the arbitration status of a dispute.
- `isValid(bytes32 _disputeId)`: Indicates whether the dispute has been arbitrated.
- `startResolution(bytes32 _disputeId)`: Starts the arbitration process by calling `resolve` on the arbitrator and flags the dispute as `Active`.
- `resolveDispute(bytes32 _disputeId)`: Resolves the dispute by getting the answer from the arbitrator and notifying the oracle.
- `decodeRequestData(bytes32 _requestId)`: Returns the decoded data for a request.

### Request Parameters

- `_arbitrator`: The address of the arbitrator. The contract must follow the `IArbitrator` interface.

## 3. Key Mechanisms & Concepts

The Arbitrator Module uses an external arbitrator contract to resolve disputes. The arbitration process can be in one of three states:
- Unknown (default)
- Active
- Resolved

The process starts with the `startResolution` function, which sets the dispute status to `Active`. The `resolveDispute` function is then used to get the answer from the arbitrator and update the dispute status to `Resolved`.

## 4. Gotchas

- The status of the arbitration is stored in the `_disputeData` mapping along with the dispute status. They're both packed in a `uint256`.

- The `startResolution` function will revert if the arbitrator address is the address zero.

- If the chosen arbitrator does not implement `resolve` nor `getAnswer` function, the dispute will get stuck in the `Active` state.
