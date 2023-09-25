# Response

## Introduction

The Response module is a vital part of any request that manages the requirements the requester has for the proposers, such as holding an NFT, being in a pre-defined list of addresses or providing a bond.

Prophet's Response modules:
- [BondedResponseModule](./response/bonded_response_module.md) that requires a proposer to post a bond first, which will be returned upon request finalization or slashed in case of a successful dispute.

## Creating a Response Module

To build a Response module, simply inherit from `IResponseModule` and the `Module` abstract contract, create the `RequestParameters` struct and define the logic for proposing, deleting and finalizing responses.

A Response module should take care of the following:
- Defining the criteria for proposers to be able to answer the request
- Setting the rules for the responses, such as validations or deadlines
- Handling the rewards for proposing a valid response

While developing a Response module, keep in mind that the criteria that is too narrow might result in a lack of responses, while criteria that is too broad might result in a large number of invalid responses.
