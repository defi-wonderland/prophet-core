# HTTP Request Module

See [IHttpRequestModule.sol](/solidity/interfaces/modules/request/IHttpRequestModule.sol/interface.IHttpRequestModule.md) for more details.

## 1. Introduction

The `HttpRequestModule` is a contract that allows users to request HTTP calls.

## 2. Contract Details

### Key Methods

- `decodeRequestData(bytes32 _requestId)`: This method decodes the data for a request given its ID. It returns the URL, HTTP method, body, accounting extension, payment token, and payment amount associated with the request.
- `finalizeRequest(bytes32 _requestId, address)`: This method finalizes a request by paying the proposer if there is a valid response, or releases the requester bond if no valid response was provided.

### Request Parameters

- `url`: The URL to make the HTTP request to.
- `method`: The HTTP method to use.
- `body`: The query or body parameters to send with the request.
- `accountingExtension`: The address of the accounting extension to use.
- `paymentToken`: The address of the token to use for payment.
- `paymentAmount`: The amount of tokens to pay for a correct response.

## 3. Key Mechanisms & Concepts

The `HttpRequestModule` uses an enum to represent the HTTP methods (GET, POST).

## 4. Gotchas

- No support for DELETE, PUT, PATCH because they usually require some sort of authorization.
- Keep in mind that the call to the URL will likely be made multiple times by different proposers, which is especially important for POST requests.
- Providing an invalid URL or HTTP method will cause the request to become impossible to answer.
