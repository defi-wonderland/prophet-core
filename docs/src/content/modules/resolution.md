# Resolution

## Introduction

The Resolution module is responsible for providing an answer to a dispute. It is the last step of the dispute resolution process. Because of the vast amount of resolution methods, there is no general guideline for creating a Resolution module but keep in mind that some disputes cannot be resolved, in which case the Resolution module should probably refund all involved parties.

In Prophet, examples of Resolution modules include:
- [ArbitratorModule](./resolution/arbitrator_module.md) that uses an external arbitrator contract to resolve disputes.
- [ERC20ResolutionModule](./resolution/erc20_resolution_module.md) that resolves disputes based on a voting process using ERC20 tokens.
- [PrivateERC20ResolutionModule](./resolution/private_erc20_resolution_module.md) that allows users to vote on a dispute using ERC20 tokens following a commit/reveal pattern.
- [BondEscalationResolutionModule](./resolution/bond_escalation_resolution_module.md) that follows a bond escalation-like process to resolve disputes.
- [SequentialResolutionModule](./resolution/sequential_resolution_module.md) that leverages multiple resolution modules to obtain an answer.
