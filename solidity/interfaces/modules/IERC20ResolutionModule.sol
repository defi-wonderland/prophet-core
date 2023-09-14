// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//TODO: add getters

import {IResolutionModule} from './IResolutionModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IAccountingExtension} from '../extensions/IAccountingExtension.sol';
import {IOracle} from '../IOracle.sol';

interface IERC20ResolutionModule is IResolutionModule {
  struct RequestParameters {
    IAccountingExtension accountingExtension;
    IERC20 votingToken;
    uint256 minVotesForQuorum;
    uint256 timeUntilDeadline;
  }

  struct EscalationData {
    uint256 startTime;
    uint256 totalVotes;
  }

  event VoteCast(address _voter, bytes32 _disputeId, uint256 _numberOfVotes);
  event VotingPhaseStarted(uint256 _startTime, bytes32 _disputeId);

  error ERC20ResolutionModule_OnlyDisputeModule();
  error ERC20ResolutionModule_DisputeNotEscalated();
  error ERC20ResolutionModule_UnresolvedDispute();
  error ERC20ResolutionModule_VotingPhaseOver();
  error ERC20ResolutionModule_OnGoingVotingPhase();
  error ERC20ResolutionModule_NonExistentDispute();
  error ERC20ResolutionModule_AlreadyResolved();

  function escalationData(bytes32 _disputeId) external view returns (uint256 _startTime, uint256 _totalVotes);
  function castVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes) external;
  function votes(bytes32 _disputeId, address _voter) external view returns (uint256 _votes);
  function resolveDispute(bytes32 _disputeId) external;
  function getVoters(bytes32 _disputeId) external view returns (address[] memory _voters);
  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _params);
}
