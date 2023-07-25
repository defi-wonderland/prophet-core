// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16 <0.9.0;

//TODO: add getters

import {IResolutionModule} from './IResolutionModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IAccountingExtension} from '../extensions/IAccountingExtension.sol';
import {IOracle} from '../IOracle.sol';

interface IERC20ResolutionModule is IResolutionModule {
  struct EscalationData {
    uint256 startTime;
    uint256 totalVotes;
  }

  event VoteCast(address _voter, bytes32 _disputeId, uint256 _numberOfVotes);
  event VotingPhaseStarted(uint256 _startTime, bytes32 _disputeId);
  event DisputeResolved(bytes32 _disputeId, IOracle.DisputeStatus _status);

  error ERC20ResolutionModule_OnlyDisputeModule();
  error ERC20ResolutionModule_DisputeNotEscalated();
  error ERC20ResolutionModule_UnresolvedDispute();
  error ERC20ResolutionModule_VotingPhaseOver();
  error ERC20ResolutionModule_OnGoingVotingPhase();
  error ERC20ResolutionModule_NonExistentDispute();
  error ERC20ResolutionModule_AlreadyResolved();

  function escalationData(bytes32 _disputeId) external view returns (uint256 _startTime, uint256 _totalVotes);
  function totalNumberOfVotes(bytes32 _disputeId) external view returns (uint256 _numOfVotes);
  function castVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes) external;
  function votes(bytes32 _disputeId, address _voter) external view returns (uint256 _votes);
  function resolveDispute(bytes32 _disputeId) external;
  function getVoters(bytes32 _disputeId) external view returns (address[] memory _voters);
  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (
      IAccountingExtension _accountingExtension,
      IERC20 _token,
      uint256 _minVotesForQuorum,
      uint256 _timeUntilDeadline
    );
}
