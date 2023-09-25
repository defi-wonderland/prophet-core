# Request

## Introduction

All modules in the Prophet Framework are designed to handle specific parts of a request's lifecycle and the Request module is responsible for asking for the information and configuring a reward. This includes declaring the source for the response and running any necessary validations or actions specified in the `_afterSetupRequest` function.

Prophet's Request modules:
- [ContractCallRequestModule](./request/contract_call_request_module.md) to request data from a smart contract
- [HTTPRequestModule](./request/http_request_module.md) to request data from a URL
- [SparseMerkleTreeRequestModule](./request/sparse_merkle_tree_request_module.md) to request a verification of a Merkle tree

## Creating a Request Module

Creating a Request module is as simple as defining a contract that inherits from the `IRequestModule` interface and implements the necessary logic in the `_afterSetupRequest` and `finalizeRequest` hooks, as well as any custom logic.

A good Request module should take care of the following:
- Declaring the data source for proposers to be able to answer the request
- Specifying the reward for proposing a valid answer
- Providing a way for the requester to withdraw the reward if no valid answer is proposed
