# Core Contracts

The core contracts of the Prophet project are the backbone of the system responsible for keeping track of the data and routing the calls to the appropriate modules.

The core includes:
- The [`Oracle`](./oracle.md) contract, which is the main contract that connects different parts of a request
- The [`Module`](./module.md) abstract contract, which is the base for all modules
- The interfaces for the different modules, such as `IRequestModule`, `IResponseModule`, etc

For more detailed information about each contract, please refer to the respective documentation pages.

For the Request, Response, Dispute, Resolution and Finality modules, please refer to the respective sections in the [Modules](../modules/README.md) documentation.

For more technical details about the interfaces of the core contracts, please refer to the [Interfaces](../../solidity/interfaces/README.md) section in the technical documentation.

⚠️ Please note that the code has not been audited yet, so use it with caution.
