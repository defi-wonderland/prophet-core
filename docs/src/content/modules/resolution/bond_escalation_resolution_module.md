# Bond Escalation Resolution Module

## 1. Introduction

The `BondEscalationResolutionModule` is a resolution module that handles the bond escalation resolution process for disputes. During the resolution, the sides take turns pledging for or against a dispute by bonding tokens.

## 2. Contract Details

### Key Methods

- `pledgeForDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount)`: Allows users to pledge in favor of a given dispute.

- `pledgeAgainstDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount)`: Allows users to pledge against a given dispute.

- `claimPledge(bytes32 _requestId, bytes32 _disputeId)`: Allows user to claim his corresponding pledges after a dispute is resolved.

### Request Parameters

- `accountingExtension`: The accounting extension to be used.
- `bondToken`: The token to be used for bonding.
- `percentageDiff`: The percentage difference for the dispute.
- `pledgeThreshold`: The pledge threshold for the dispute.
- `timeUntilDeadline`: The time until the main deadline.
- `timeToBreakInequality`: The time to break inequality.

## 3. Key Mechanisms & Concepts

The outcome of a dispute is determined by the total pledges for and against the dispute. If the total pledges for the dispute are greater than the pledges against, the disputer wins. If the total pledges against the dispute are greater than the pledges for, the disputer loses. The difference between this module and the simple voting is the inequality timer that kicks in when the difference in pledges between the sides exceeds a set threshold. When this happens, the side with the lower amount of pledges has a set amount of time to increase their pledges to match the other side. If they fail to do so, the dispute is resolved in favor of the other side.
