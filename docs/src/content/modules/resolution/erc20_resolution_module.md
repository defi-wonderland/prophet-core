# ERC20 Resolution Module

## 1. Introduction

The `ERC20ResolutionModule` is a dispute resolution module that decides on the outcome of a dispute based on a vote.

## 2. Contract Details

### Key Methods

- `decodeRequestData(bytes32 _requestId)`: Decodes the request data associated with a given request ID.
- `startResolution(bytes32 _disputeId)`: Starts the resolution process for a given dispute.
- `castVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes)`: Allows a user to cast votes for a dispute.
- `resolveDispute(bytes32 _disputeId)`: Resolves a dispute based on the votes cast.
- `getVoters(bytes32 _disputeId)`: Returns the addresses of the voters for a given dispute.

### Request Parameters

- `_accountingExtension`: The accounting extension associated with the request.
- `_token`: The ERC20 token used for voting.
- `_minVotesForQuorum`: The minimum number of votes required for a quorum.
- `_timeUntilDeadline`: The time from the escalation to the voting deadline.

## 3. Key Mechanisms & Concepts

The `ERC20ResolutionModule` uses ERC20 tokens as votes for dispute resolution. Users can cast votes for a dispute by calling the `castVote` function. The number of votes a user can cast is equal to the number of ERC20 tokens they hold.

The resolution process starts with the startResolution function, which sets the start time for the voting phase. Once the voting phase is over, the `resolveDispute` function is called to resolve the dispute based on the votes cast. If the total number of votes cast meets the minimum requirement for a quorum, the dispute is resolved.

## 4. Gotchas

- It is implied that the voters are incentivized to vote either because they're the governing entity of the ERC20 and have a stake in the outcome of the dispute or because they expect to be rewarded by such an entity.
- The `castVote` function requires the user to have approved the contract to spend their ERC20 tokens.

## 5. Failure Modes

- Setting a time until deadline that's too short may result in voters not being able to participate.
- Setting the quorum that's too low may result in the dispute being resolved too early and without much participation.
