# Prophet Framework 101

## What is Prophet?

Prophet presents a versatile and fully adaptable optimistic oracle solution, transcending the boundaries of conventional dispute resolution modules. It moves away from a one-fits-all resolution system and provides customizable modules that can be fine-tuned to meet the unique requirements of each user. With its emphasis on complete control and modularity across all aspects of the system, Prophet is an open-source public good for the Optimism community.

- **Optimistic**: Prophet is an optimistic oracle, meaning that in most cases a request will be answered without any disputes. This allows for a fast and cheap capturing of the information.
- **Modular**: The framework is designed to support countless use cases by enabling the users to choose the logic of their requests. The users can choose from a variety of modules and extensions.
- **Permissionless**: Asking for or providing the data requires no approvals from any centralized party. Additionally, anyone is free to expand the system by building new modules and extensions.
- **Public good**: Prophet does not extract any value from its users.

## Key Concents

### Roles

- **Requester** creates requests in the Oracle
- **Proposer** gets rewards for providing valid answers to the requests
- **Disputer** challenges answers and gets paid if the answer is found to be invalid

### Request

A request is what is being asked for. Example requests are:

- What's the price of oil on April 1st?
- Was the temperature in Madrid above 30 degrees on 1st July 2023?

At any time, a request will be in one of the following states

1. No response has been proposed yet. In this case either a response can be proposed or, if the submission deadline has passed, the request's state can be changed to finalized without responses, meaning it will never be answered.

2. A response has been proposed. The response is considered valid until claimed otherwise by a disputer. If undisputed, the response becomes finalized after the submission deadline is over.

3. A response has been proposed and disputed. Disputing a response usually opens up a window for proposing a new response. If the dispute gets resolved in favor of the proposer, the request can be finalized. If the resolution favors the disputer, the proposer's bond is transferred to the disputer. Inconclusive results are possible, for instance if a vote fails to reach quorum.

4. The request has been finalized. From this point it's unchangeable and if there is a response, it can be safely used by other contracts.

### Response

A response is a proposed answer to a request. The submission is open for anyone matching the criteria defined in the response module. For instance it could be an NFT holder, an address with a sufficient bond or an entity from a list of approved addresses. An undisputed response can be retracted by the proposer to give them a chance to correct a mistake.

### Dispute

Disputes are the core mechanism of an optimistic oracle protecting it from malicious actors. A dispute can be raised by anyone meeting the requirements exposed by the dispute module of a particular request. A multitude of options is available for the dispute module, from simple voting to more complex mechanisms.

Dispute modules are designed to reduce the number of calls to the resolution modules, for instance by allowing a bond escalation period before the dispute is escalated to the resolution module.

In some cases a dispute can be resolved on-chain, unlocking atomical resolution and finalization of the request and eliminating the need for a resolution module.

### Oracle

This smart-contract coordinates and ensures the correct use and functionality of in-use modules. It's the entry point/proxy for external calls into the modules.

The oracle only has power over storing requests data, everything else is decided by the modules used in the requests.

### Modules

Modules are the lego blocks for requests. They're responsible for the logic of the request, such as who is allowed to propose the answers, where to get them, and how to resolve disputes.

Since building a module is permissionless, the users should pay extra attention to the contracts they choose to interact with, verify their safety and compatibility with other modules.

Module-specific logic should be implemented in hooks such as
- `setupRequest`
- `afterSetupRequest`
- `finalizeRequest`
- `deleteResponse`

### Extensions

Extensions are smart-contracts that are extending the functionality of the modules. They can be used to store data, manage user balances, and more. One example of an extension would be the accounting extension, which is used to keep user funds and streamline user interactions with the oracle by eliminating the need for constant fund transfers.
