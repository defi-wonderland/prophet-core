# Bond Escalation Accounting Extension

See [IBondEscalationAccounting.sol](/solidity/interfaces/extensions/IBondEscalationAccounting.sol/interface.IBondEscalationAccounting.md) for more details.

## 1. Introduction

The `BondEscalationAccounting` contract is an extension that allows users to deposit and pledge funds to be used for bond escalation. It provides mechanisms for pledging tokens and paying out rewards to the winning pledgers.

## 2. Contract Details

### Key Methods

- `deposit`: This function allows a user to deposit a specific amount of a token into the accounting extension. If ETH is being deposited, it is wrapped to WETH.
- `withdraw`: By calling this function, a user can withdraw a specific amount of a token from the accounting extension.
- `pledge`: This function allows a user to pledge a certain amount of tokens for a specific dispute. The pledged tokens are deducted from the user's balance and added to the total pledges for the dispute.
- `settleBondEscalation`: This function unlocks the rewards for the winners.
- `claimEscalationReward`: Calculates and transfers the caller's part of the reward to them.
- `releasePledge`: This function allows a module to release a user's tokens.

## 3. Key Mechanisms & Concepts

- Pledging: Users can pledge tokens for or against a dispute. The pledged tokens are locked and cannot be used until the dispute is resolved.

- Deposits: Users can deposit tokens into the extension. Deposits can be made in any ERC20 token, ETH deposits will be converted to WETH.

- Withdrawals: Users can withdraw their tokens at any time. The withdrawal operation reduces the user's balance in the extension and transfers the tokens back to the user's address. Locked tokens can't be withdrawn until they're released by a module.

## 4. Gotchas

- Before depositing ERC20 tokens, users must first approve the extension to transfer the tokens on their behalf.
