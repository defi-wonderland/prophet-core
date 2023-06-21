// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16 <0.9.0;

//TODO: add getters

import {IOracle} from '../IOracle.sol';
import {IResolutionModule} from './IResolutionModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IAccountingExtension} from '../extensions/IAccountingExtension.sol';

interface IERC20ResolutionModule is IResolutionModule {
  struct EscalationData {
    uint128 startTime;
    uint128 results; // 0 = Escalated, 1 = Disputer Won, 2 = Disputer Lost
    uint256 disputerBond;
    uint256 totalVotes;
  }

  struct VoterData {
    address voter;
    uint256 numOfVotes;
  }

  event VoteCast(address _voter, bytes32 _disputeId, uint256 _numberOfVotes);
  event VotingPhaseStarted(uint128 _startTime, bytes32 _disputeId);
  event DisputeResolved(bytes32 _disputeId);

  error ERC20ResolutionModule_OnlyDisputeModule();
  error ERC20ResolutionModule_DisputeNotEscalated();
  error ERC20ResolutionModule_UnresolvedDispute();
  error ERC20ResolutionModule_VotingPhaseOver();
  error ERC20ResolutionModule_OnGoingVotingPhase();
  error ERC20ResolutionModule_NonExistentDispute();

  function escalationData(bytes32 _disputeId)
    external
    view
    returns (uint128 _startTime, uint128 _results, uint256 _disputerBond, uint256 _totalVotes);
  // TODO: create getter -- see if its possible to declare this
  // function votes(bytes32 _disputeId) external view returns (VoterData memory _voterData);
  function totalNumberOfVotes(bytes32 _disputeId) external view returns (uint256 _numOfVotes);
  function castVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes) external;
  function resolveDispute(bytes32 _disputeId) external;
  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (
      IAccountingExtension _accountingExtension,
      IERC20 _token,
      uint256 _disputerBondSize,
      uint256 _minQuorum,
      uint256 _timeUntilDeadline
    );
}
