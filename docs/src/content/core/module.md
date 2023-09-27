# Module

See [IModule.sol](/solidity/interfaces/IModule.sol/interface.IModule.md) for more details.

## 1. Introduction

`Module` is an abstract contract that defines common functions and modifiers. A module is supposed to inherit the abstract contract and implement specific logic in one of the hooks, for example `_afterSetupRequest`.

## 2. Contract Details

### Key Methods

All public functions in the abstract contract are callable only by the oracle.

- `setupRequest` is a hook executed on request creation. Apart from saving the request data in the module, it can run can run validations, bond funds or perform any other action specified in the `_afterSetupRequest` function.
- `finalizeRequest` is a hook executed on request finalization. It's vital to remember that there are [2 ways of finalizing a request](oracle.md#finalization) and this function must handle both of them.

## 3. Key Mechanisms & Concepts

### Request Data

The `requestData` is a mapping that associates each request's unique identifier (`requestId`) with its corresponding parameters. This mapping is public, allowing for the data of any request to be accessed using its ID.

## 4. Gotchas

It's worth noting that if a module does not implement a hook, it will still be called by the oracle.
