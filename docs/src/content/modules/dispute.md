# Dispute

## Introduction

The Dispute module is a crucial component of the Prophet Framework that manages the process of challenging responses, improving the security and trustworthiness of the data.

In Prophet, examples of Dispute modules include:
- [BondedDisputeModule](./dispute/bonded_dispute_module.md) that requires a challenger to post a bond first, which will be returned upon successful dispute resolution or slashed in case of an unsuccessful dispute.
- [BondEscalationModule](./dispute/bond_escalation_module.md) in which the sides take turns increasing the bond until one of them gives up or until they reach a limit.
- [CircuitResolverModule](./dispute/circuit_resolver_module.md) that allows for the dispute to be resolved on-chain.
- [RootVerificationModule](./dispute/root_verification_module.md) that, similarly to the `CircuitResolverModule`, enables atomical on-chain resolution of disputes.

## Dispute Types

- Pre-dispute: This type of Dispute modules aims to settle disputes before they reach the Resolution module. `BondEscalationModule` is an example of a pre-dispute module.

- Atomical dispute: This type of dispute relies on an external contract to atomically resolve the dispute as soon as it's started. In this case the Resolution module might not be needed at all. `CircuitResolverModule` and `RootVerificationModule` are examples of atomical dispute modules.

## Developing a Dispute Module

When developing a Dispute module, you should:

- Define the criteria for challengers to be able to initiate a dispute
- Set the rules for the disputes, such as validations or deadlines
- Handle the rewards or slashing resulting from the dispute resolution
- Specify the next steps if a dispute should be moved to the Resolution module

Ensure that the dispute criteria are not too narrow to prevent valid disputes from being raised. Conversely, criteria that are too broad might result in a large number of unnecessary disputes.
