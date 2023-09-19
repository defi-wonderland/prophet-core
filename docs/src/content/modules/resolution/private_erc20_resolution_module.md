# Private ERC20 Resolution Module

## 1. Introduction

The `PrivateERC20ResolutionModule` is a contract that allows users to vote on a dispute using ERC20 tokens. The voting process follows a commit/reveal pattern to ensure that votes are kept secret until the voting period ends.

## 2. Contract Details

### Key methods

- `decodeRequestData(bytes32 _requestId)`: Returns the decoded data for a request.
- `startResolution(bytes32 _disputeId)`: Starts the committing phase for a dispute.
- `commitVote(bytes32 _requestId, bytes32 _disputeId, bytes32 _commitment)`: Stores a commitment for a vote cast by a voter.
- `revealVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes, bytes32 _salt)`: Reveals a vote cast by a voter.
- `resolveDispute(bytes32 _disputeId)`: Resolves a dispute by tallying the votes and executing the winning outcome.
- `computeCommitment(bytes32 _disputeId, uint256 _numberOfVotes, bytes32 _salt)`: Computes a valid commitment for the revealing phase.

### Request Parameters

- `_accountingExtension`: The address of the accounting extension associated with the given request.
- `_votingToken`: The address of the token used for voting.
- `_minVotesForQuorum`: The minimum number of votes required for a dispute to be resolved.
- `_committingTimeWindow`: The time window for the committing phase.
- `_revealingTimeWindow`: The time window for the revealing phase.

## 3. Key Mechanisms & Concepts

- Committing phase: From the beginning of the dispute until the committing deadline, the votes are free to cast their votes and store their commitments.
- Revealing phase: After the committing deadline until the revealing deadline, the voters can reveal their votes by providing the commitment and the salt used to generate it.
- Salt: A random value used to generate the commitment, making it impossible to guess.

## 4. Gotchas

- It is implied that the voters are incentivized to vote either because they're the governing entity of the ERC20 and have a stake in the outcome of the dispute or because they expect to be rewarded by such an entity.
- The `commitVote` function allows committing multiple times and overwriting a previous commitment.
- The `revealVote` function requires the user to have previously approved the module to transfer the tokens.

