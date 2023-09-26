// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IResolutionModule} from './IResolutionModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IAccountingExtension} from '../../extensions/IAccountingExtension.sol';

/*
  * @title PrivateERC20ResolutionModule
  * @notice Module allowing users to vote on a dispute using ERC20 
  * tokens through a commit/reveal pattern. 
  */
interface IPrivateERC20ResolutionModule is IResolutionModule {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice A commitment has been provided by a voter
   * @param _voter The user who provided a commitment of a vote
   * @param _disputeId The id of the dispute being voted on
   * @param _commitment The commitment provided by the voter
   */
  event VoteCommitted(address _voter, bytes32 _disputeId, bytes32 _commitment);

  /**
   * @notice A vote has been revealed by a voter providing
   * the salt used to compute the commitment
   * @param _voter The user who revealed his vote
   * @param _disputeId The id of the dispute being voted on
   * @param _numberOfVotes The number of votes cast
   */
  event VoteRevealed(address _voter, bytes32 _disputeId, uint256 _numberOfVotes);

  /**
   * @notice The phase of committing votes has started
   * @param _startTime The timestamp at which the phase started
   * @param _disputeId The id of the dispute being voted on
   */
  event CommittingPhaseStarted(uint256 _startTime, bytes32 _disputeId);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the dispute has not been escalated
   */
  error PrivateERC20ResolutionModule_DisputeNotEscalated();

  /**
   * @notice Thrown when trying to commit a vote after the committing deadline
   */
  error PrivateERC20ResolutionModule_CommittingPhaseOver();

  /**
   * @notice Thrown when trying to reveal a vote after the revealing deadline
   */
  error PrivateERC20ResolutionModule_RevealingPhaseOver();

  /**
   * @notice Thrown when trying to resolve a dispute during the committing phase
   */
  error PrivateERC20ResolutionModule_OnGoingCommittingPhase();

  /**
   * @notice Thrown when trying to resolve a dispute during the revealing phase
   */
  error PrivateERC20ResolutionModule_OnGoingRevealingPhase();

  /**
   * @notice Thrown when trying to resolve a dispute that does not exist
   */
  error PrivateERC20ResolutionModule_NonExistentDispute();

  /**
   * @notice Thrown when trying to commit an empty commitment
   */
  error PrivateERC20ResolutionModule_EmptyCommitment();

  /**
   * @notice Thrown when trying to reveal a vote with data that does not match the stored commitment
   */
  error PrivateERC20ResolutionModule_WrongRevealData();

  /**
   * @notice Thrown when trying to resolve a dispute that is already resolved
   */
  error PrivateERC20ResolutionModule_AlreadyResolved();

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the request as stored in the module
   * @param accountingExtension The accounting extension used to bond and release tokens
   * @param token The token used to vote
   * @param minVotesForQuorum The minimum amount of votes to win the dispute
   * @param committingTimeWindow The amount of time to commit votes from the escalation of the dispute
   * @param revealingTimeWindow The amount of time to reveal votes from the committing phase
   */
  struct RequestParameters {
    IAccountingExtension accountingExtension;
    IERC20 votingToken;
    uint256 minVotesForQuorum;
    uint256 committingTimeWindow;
    uint256 revealingTimeWindow;
  }

  /**
   * @notice Escalation data for a dispute
   * @param startTime The timestamp at which the dispute was escalated
   * @param totalVotes The total amount of votes cast for the dispute
   */

  struct Escalation {
    uint256 startTime;
    uint256 totalVotes;
  }

  /**
   * @notice Voting data for each voter
   * @param numOfVotes The amount of votes cast for the dispute
   * @param commitment The commitment provided by the voter
   */
  struct VoterData {
    uint256 numOfVotes;
    bytes32 commitment;
  }

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the escalation data for a dispute
   * @param _disputeId The id of the dispute
   * @return _startTime The timestamp at which the dispute was escalated
   * @return _totalVotes The total amount of votes cast for the dispute
   */
  function escalations(bytes32 _disputeId) external view returns (uint256 _startTime, uint256 _totalVotes);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Starts the committing phase for a dispute
   * @dev Only callable by the Oracle
   * @param _disputeId The id of the dispute to start resolution of
   */
  function startResolution(bytes32 _disputeId) external;

  /**
   * @notice Stores a commitment for a vote cast by a voter
   * @dev Committing multiple times and overwriting a previous commitment is allowed
   * @param _requestId The id of the request being disputed
   * @param _disputeId The id of the dispute being voted on
   * @param _commitment The commitment computed from the provided data and the user's address
   */
  function commitVote(bytes32 _requestId, bytes32 _disputeId, bytes32 _commitment) external;

  /**
   * @notice Reveals a vote cast by a voter
   * @dev The user must have previously approved the module to transfer the tokens
   * @param _requestId The id of the request being disputed
   * @param _disputeId The id of the dispute being voted on
   * @param _numberOfVotes The amount of votes being revealed
   * @param _salt The salt used to compute the commitment
   */
  function revealVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes, bytes32 _salt) external;

  /**
   * @notice Resolves a dispute by tallying the votes and executing the winning outcome
   * @dev Only callable by the Oracle
   * @param _disputeId The id of the dispute being resolved
   */
  function resolveDispute(bytes32 _disputeId) external;

  /**
   * @notice Returns the decoded data for a request
   * @param _requestId The ID of the request
   * @return _params The struct containing the parameters for the request
   */
  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _params);

  /**
   * @notice Computes a valid commitment for the revealing phase
   * @param _disputeId The id of the dispute being voted on
   * @param _numberOfVotes The amount of votes being cast
   * @return _commitment The commitment computed from the provided data and the user's address
   */
  function computeCommitment(
    bytes32 _disputeId,
    uint256 _numberOfVotes,
    bytes32 _salt
  ) external view returns (bytes32 _commitment);
}
