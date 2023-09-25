# Oracle

## 1. Introduction

The Oracle serves as the central part of the Prophet framework. It performs the following functions:

- Managing requests, responses and disputes.
- Routing function calls to appropriate modules.
- Keeping data synchronized between different modules.
- Providing the users with the full picture of their request, response or dispute.

The Oracle does not handle any transfers, utilizing the extensions for that functionality.

## 2. Contract Details

### Key Methods:

- `createRequest`: Creates a new request.
- `proposeResponse`: Proposes a response to a request.
- `disputeResponse`: Disputes a response to a request.
- `deleteResponse`: Deletes a response to a request.
- `escalateDispute`: Escalates a dispute to the next level.
- `updateDisputeStatus`: Updates the status of a dispute.
- `finalize`: Finalizes a request.

## 3. Key Mechanisms & Concepts

### Request vs Full Request vs New Request

The oracle defines 3 structures representing a request:

- `Request` which is stored in `_requests` mapping. It includes the addresses of the modules and additional information like the requester address and the creation and finalization timestamps. It can be retrieved with `getRequest` function.
- `FullRequest` unlike the Request struct, this one also includes the data used to configure the modules. `getFullRequest` function can be used to retrieve it.
- `NewRequest` is a struct used in `createRequest`. It lacks the timestamps and the requester address, which are set by the oracle, but includes the modules data.

### Finalization
The oracle supports 2 ways of finalizing a request.

1. In case there is a non-disputed response, the request can be finalized by calling `finalize` function and providing the response ID. The oracle will call `finalizeRequest` on the modules and mark the request as finalized. Generally the `finalizeRequest` hook will issue the reward to the proposer.

2. If no responses have been submitted, or they're all disputed, the request can be finalized by calling `finalize` function without a response ID. The same hook will be executed in all modules, refunding the requester and marking the request as finalized.

## 4. Gotchas

### Request misconfiguration

Due to the modular and open nature of the framework, the oracle does not have any rules or validations, and a request is deemed correct unless it reverts on creation (`setupRequest`). It’s the requester’s responsibility to choose sensible parameters and avoid the request being unattractive to proposers and disputers, impossible to answer or finalize.

The same can be said about engaging with a request. Off-chain validation must be done prior to proposing or disputing any response to avoid the loss of funds. We strongly encourage keeping a list of trusted modules and extensions and avoid interactions with unverified ones.
