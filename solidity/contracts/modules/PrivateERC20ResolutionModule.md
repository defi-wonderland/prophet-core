# Private ERC20 Resoultion Module | Idea Draft

### VoterData

- bytes32 `commitment` instead of uint256 `numOfVotes` (maybe both?)

### Request Data

- module's request data must add a `commitmentTimeWindow` for users to commit
their votes

- `_timeUntilDeadline` could be renamed to have both `commitmentTimeWindow` and `revealingTimeWindow`

### Create commitment?

`function createCommitment(bytes32 _disputeId, uint256 _numberOfVotes, bytes32 _salt) pure view returns (bytes32 _commitment)`

### Commiting

`function commitVote(bytes32 _requestId, bytes32 _disputeId, bytes32 _commitment)`

- where `_commitment` is the keccak256 hash of `abiEncodePacked(address msg.sender, bytes32 _disputeId, uint256 numberOfVotes, bytes32 salt)`

- all checks done in the public `ERC20ResolutionModule` but checking for `commitmentTimeWindow`

- `votes[_disputeId].push(VoterData({voter: msg.sender, commitment: _commitment, numberOfVotes: 0}))`

- no token transfer

- `emit VoteCommited(msg.sender, _disputeId, _commitment)`

### Revealing

`function revealVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes, bytes32 _salt)`

- check for `revealingTimeWindow`

- check if user has commited and/or revealed a vote

- check that `hash(encode(msg.sender, _disputeId, _numberOfVotes, _salt)) == userVoteData.commitment`

- `totalNumberOfVotes += _numberOfVotes`

- `userVoteData.numberOfVotes = _numberOfVotes` ?

- token transfer from voter to contract

- `emit VoteRevealed(msg.sender, _disputeId, _numberOfVotes)`

### Resolving dispute

The dispute resolution remains the same just checking that `revealingTimeWindow` has ended.

### Questions

- the salt must only be provided at revealing. how will it be computated? where will it be stored?

- users must approve the resolution contract in order to transfer voting tokens. since the amount is not known, how much must the voter approve and when4?

### Example execution flow

1. commitment time window opens.
2. user generates a commitment hash.
3. user approves the module for an X amount of tokens TBD
4. user calls `commitVote` and the commitment is stored.
5. revealing time window opens.
6. user calls `revealVote` and the tokens are transferred to the contract. if the contract is not able to transfer the tokens from the user, it reverts, allowing the user to correctly approve the tokens.
7. revealing time window closes and `resolveDispute` is called. works the same as the public module.

If the user did not approve the tokens or approved the incorrect amount, they still can correct their mistake. Otherwise, the tokens are not transferred and the votes not tallied. Just a reveal-less commitment remains stored.

