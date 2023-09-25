# Extensions

Extensions are smart contracts that expand the functionality of modules. They're not required to be used but can provide safe space for storing the user balances outside of modules, making interactions with the Oracle easier. Extensions are supposed to be reused by multiple modules, handling multiple requests at the same time.

Prophet's shipped with 2 extensions:
- [AccountingExtension](./accounting.md) that is used to keep track of the bonds and payments
- [BondEscalationAccountingExtension](./bond_escalation_accounting.md) that is similar to the `AccountingExtension` but tailored for the `BondEscalation` module
