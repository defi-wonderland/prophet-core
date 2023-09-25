# Bond Escalation Module

## 1. Introduction

The Bond Escalation Module is a contract that allows users to have the first dispute of a request go through the bond escalation mechanism. This mechanism allows for a dispute to be escalated by pledging more funds in favor or against the dispute. The module is designed to prevent last-second breaking of ties by adding a tying buffer at the end of the bond escalation deadline.

## 2. Contract Details

### Key Methods

- `disputeResponse(bytes32 _requestId, bytes32 _responseId, address _disputer, address _proposer)`: This function is called to dispute a response and start the bond escalation process. In case of a second and subsequent disputes, the function bonds the disputer's funds but does not start the bond escalation.
- `disputeEscalated(bytes32 _disputeId)`: This function is called when a dispute has been escalated, putting the bond escalation on hold. It is only possible if there is a tie between the sides of the dispute.
- `pledgeForDispute(bytes32 _disputeId)`: This function allows a user to pledge in favor of a dispute.
- `pledgeAgainstDispute(bytes32 _disputeId)`: This function allows a user to pledge against a dispute.
- `settleBondEscalation(bytes32 _requestId)`: This function settles the bond escalation process of a given request, allowing the winning pledgers to withdraw their funds from the bond escalation accounting extension.

### Request Parameters

The request parameters for the Bond Escalation Module are:

- `accountingExtension`: The address of the accounting extension associated with the given request.
- `bondToken`: The address of the token associated with the given request.
- `bondSize`: The amount to bond to dispute or propose an answer for the given request.
- `numberOfEscalations`: The maximum allowed escalations or pledges for each side during the bond escalation process.
- `bondEscalationDeadline`: The timestamp at which bond escalation process finishes when pledges are not tied.
- `tyingBuffer`: The number of seconds to extend the bond escalation process to allow the losing party to tie if at the end of the initial deadline the pledges weren't tied.
- `challengePeriod`: The number of seconds disputers have to challenge the proposed response since its creation.

## 3. Key Mechanisms & Concepts

- Bond Escalation: The process of rasing stakes and pledging for one of the sides of a dispute. The sides take turns bonding funds until the bond escalation deadline. If the number of pledges in favor of the dispute is not equal to the number of pledges against the dispute at the end of the bond escalation deadline plus the tying buffer, the bond escalation accountancy can settled. In case of a tie, the dispute must be escalated to the resolution module.
- Pledge: Bonded funds that are used to support or oppose a dispute.

## 4. Gotchas

- Only the first dispute of a request can go through the bond escalation mechanism.
- After the bond escalation has finished, the winning side should withdraw their funds by calling `claimEscalationReward` on the bond escalation accounting extension.
- The funds of the losing side of the bond escalation will be slashed and given to the winners.
