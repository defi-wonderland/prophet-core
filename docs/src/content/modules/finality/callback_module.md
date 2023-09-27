# Callback Module

See [ICallbackModule.sol](/solidity/interfaces/modules/finality/ICallbackModule.sol/interface.ICallbackModule.md) for more details.

## 1. Introduction

The Callback Module is a finality module that allows users to call a function on a contract as a result of a request being finalized. It is useful to notify a contract about the outcome of a request.

## 2. Contract Details

### Key Methods

- `decodeRequestData(bytes32 _requestId)`: Returns the decoded data for a request.
- `finalizeRequest(bytes32 _requestId, address)`: Executing the callback call on the target.

### Request Parameters

- `target`: The target address for the callback.
- `data`: The calldata forwarded to the target.

## 3. Key Mechanisms & Concepts

As any finality module, the `CallbackModule` implements the `finalizeRequest` function which executes the chosen function with the given parameters on the target contract.

## 4. Gotchas

- The success of the callback call in `finalizeRequest` is purposely not checked, specifying a function or parameters that lead to a revert will not stop the request from being finalized.
- The target must be a contract.
