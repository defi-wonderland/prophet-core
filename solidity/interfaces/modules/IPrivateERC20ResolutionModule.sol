// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16 <0.9.0;

//TODO: add getters

import {IResolutionModule} from './IResolutionModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IAccountingExtension} from '../extensions/IAccountingExtension.sol';
import {IOracle} from '../IOracle.sol';

interface IPrivateERC20ResolutionModule is IResolutionModule {
  struct EscalationData {
    uint128 startTime;
    uint256 totalVotes;
  }

  struct VoterData {
    address voter;
    uint256 numOfVotes;
  }

  event VoteCommited(address _voter, bytes32 _disputeId, bytes32 _commitment);
  event VoteRevealed(address _voter, bytes32 _disputeId, uint256 _numberOfVotes);
  event CommitingPhaseStarted(uint128 _startTime, bytes32 _disputeId);
  event RevealingPhaseStarted(uint128 _startTime, bytes32 _disputeId);
  event DisputeResolved(bytes32 _disputeId, IOracle.DisputeStatus _status);

  error PrivateERC20ResolutionModule_OnlyDisputeModule();
  error PrivateERC20ResolutionModule_DisputeNotEscalated();
  error PrivateERC20ResolutionModule_UnresolvedDispute();
  error PrivateERC20ResolutionModule_CommitingPhaseOver();
  error PrivateERC20ResolutionModule_RevealingPhaseOver();
  error PrivateERC20ResolutionModule_OnGoingCommitingPhase();
  error PrivateERC20ResolutionModule_OnGoingRevealingPhase();
  error PrivateERC20ResolutionModule_NonExistentDispute();
  error PrivateERC20ResolutionModule_EmptyCommitment();
  error PrivateERC20ResolutionModule_AlreadyCommited();
  error PrivateERC20ResolutionModule_NeverCommited();
  error PrivateERC20ResolutionModule_WrongRevealData();
  error PrivateERC20ResolutionModule_AlreadyResolved();

  function escalationData(bytes32 _disputeId) external view returns (uint128 _startTime, uint256 _totalVotes);
  // TODO: create getter -- see if its possible to declare this
  // function votes(bytes32 _disputeId) external view returns (VoterData memory _voterData);
  function totalNumberOfVotes(bytes32 _disputeId) external view returns (uint256 _numOfVotes);
  function commitVote(bytes32 _requestId, bytes32 _disputeId, bytes32 _commitment) external;
  function revealVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes, bytes32 _salt) external;
  function resolveDispute(bytes32 _disputeId) external;
  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (
      IAccountingExtension _accountingExtension,
      IERC20 _token,
      uint256 _minVotesForQuorum,
      uint256 _commitingTimeWindow,
      uint256 _revealingTimeWindow
    );
}
