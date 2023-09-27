# Bonded Response Module

See [IBondedResponseModule.sol](/solidity/interfaces/modules/response/IBondedResponseModule.sol/interface.IBondedResponseModule.md) for more details.

## 1. Introduction

The Bonded Response Module is a contract that allows users to propose a response for a request by bonding tokens.

## 2. Contract Details

### Key Methods

- `decodeRequestData(bytes32 _requestId)`: Returns the decoded data for a request.
- `propose(bytes32 _requestId, address _proposer, bytes calldata _responseData)`: Proposes a response for a request, bonding the proposer's tokens.
- `deleteResponse(bytes32 _requestId, bytes32 _responseId, address _proposer)`: Allows a user to delete an undisputed response they proposed before the deadline, releasing the bond.
- `finalizeRequest(bytes32 _requestId, address _finalizer)`: Finalizes the request.

### Request Parameters

- `accountingExtension`: The address holding the bonded tokens. It must implement the [IAccountingExtension.sol](/solidity/interfaces/extensions/IAccountingExtension.sol/interface.IAccountingExtension.md) interface.
- `bondToken`: The ERC20 token used for bonding.
- `bondSize`: The amount of tokens the disputer must bond to be able to dispute a response.
- `deadline`: The timestamp at which the module stops accepting new responses for a request and it becomes finalizable.

## 3. Key Mechanisms & Concepts

- Deleting a response: If a proposer realizes the response they've submitted is incorrect, they can delete it. Note that disputed responses cannot be taken back.

- Early finalization: It is possible for pre-dispute modules to atomically calculate the correct response on-chain, decide on the result of a dispute and finalize the request before its deadline.

## 4. Gotchas

- In case of no valid responses, a request can be finalized after the deadline and the requester will get back their tokens.
- A proposer might submit a response 1 block before the deadline and finalize it in the next block, making it impossible to dispute.
- Users cannot propose a response after the deadline for a request.
- Users cannot propose a response if an undisputed response has already been proposed.
- Users cannot delete a response after the proposing deadline.
