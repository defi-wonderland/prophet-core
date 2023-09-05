# Module

## 1. Introduction

`Module` is an abstract contract that defines common functions and modifiers. A module is supposed to inherit the abstract contract and implement specific logic in one of the hooks, for example `_afterSetupRequest`.

## 2. Contract Details

### Key Methods:

All public functions in the abstract contract are callable only by the oracle.

- `setupRequest` is a hook executed on request creation. Apart from saving the request data in the module, it can run can run validations, bond funds or perform any other action specified in the `_afterSetupRequest` function.
- `finalizeRequest` is a hook executed on request finalization. It's vital to remember that there are [2 ways of finalizing a request](oracle.md#finalization) and this function must handle both of them.

### Contract Parameters

## 3. Key Mechanisms & Concepts

## 4. Gotchas

## 5. Failure Modes
