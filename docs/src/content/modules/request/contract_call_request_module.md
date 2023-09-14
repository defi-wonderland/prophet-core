# Contract Call Request Module

## 1. Introduction

The `ContractCallRequestModule` is a module for requesting on-chain information. It specifies the source and the reward for a correct response.

## 2. Contract Details

### Key Methods:

- `decodeRequestData(bytes32 _requestId)`: This method decodes the request data for a given request ID. It returns the target contract address, the function selector, the encoded arguments of the function to call, the accounting extension to bond and release funds, the payment token, and the payment amount.

- `finalizeRequest(bytes32 _requestId, address)`: This method finalizes a request by paying the response proposer. It is only callable by the oracle.

### Request Parameters

- `_target`: The address of the contract to get the response from.
- `_functionSelector`: The function that returns the response to the request.
- `_data`: The data to pass to the function.
- `_accountingExtension`: The address holding the bonded tokens. It must implement the `IAccountingExtension` interface.
- `_paymentToken`: The ERC20 token used for paying the proposer.
- `_paymentAmount`: The amount of tokens the proposer will receive for a correct response.

## 3. Key Mechanisms & Concepts

Check out [Accounting Extension](../../extensions/accounting.md).

## 4. Gotchas

- The proposers must keep a list of allowed targets and function selectors and only interact with the contracts they trust. One obvious trick is to use `transfer` as the function to call, which would allow the requester to steal the proposer's funds.

## 5. Failure Modes

- Misconfiguring the data or choosing a function that does not exist on the target would render the request impossible to answer.
