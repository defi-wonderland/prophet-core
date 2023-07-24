// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IERC20ResolutionModule} from '../../interfaces/modules/IERC20ResolutionModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {Module} from '../Module.sol';

// TODO: Discuss about this module's incentives for voters. Right now there are no incentives for them to vote. There's the possibility of adding the bonded amount of the disputer/proposer as rewards
//       but that would get highly diluted - and due to the nature of how updateDisputeStatus work, this would need a custom dispute module that doesn't settle payment between proposer and disputer
//       as this would all get handled in this module.

contract ERC20ResolutionModule is Module, IERC20ResolutionModule {
  using SafeERC20 for IERC20;

  mapping(bytes32 _disputeId => EscalationData _escalationData) public escalationData;
  mapping(bytes32 _disputeId => VoterData[]) public votes;
  mapping(bytes32 _disputeId => uint256 _numOfVotes) public totalNumberOfVotes;

  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() external pure returns (string memory _moduleName) {
    return 'ERC20ResolutionModule';
  }

  function decodeRequestData(bytes32 _requestId)
    public
    view
    returns (
      IAccountingExtension _accountingExtension,
      IERC20 _token,
      uint256 _minVotesForQuorum,
      uint256 _timeUntilDeadline
    )
  {
    (_accountingExtension, _token, _minVotesForQuorum, _timeUntilDeadline) =
      abi.decode(requestData[_requestId], (IAccountingExtension, IERC20, uint256, uint256));
  }

  function startResolution(bytes32 _disputeId) external onlyOracle {
    escalationData[_disputeId].startTime = block.timestamp;
    emit VotingPhaseStarted(block.timestamp, _disputeId);
  }

  // Casts vote in favor of dispute
  function castVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes) public {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    if (_dispute.createdAt == 0) revert ERC20ResolutionModule_NonExistentDispute();

    EscalationData memory _escalationData = escalationData[_disputeId];
    if (_escalationData.startTime == 0) revert ERC20ResolutionModule_DisputeNotEscalated();

    (, IERC20 _token,, uint256 _timeUntilDeadline) = decodeRequestData(_requestId);
    uint256 _deadline = _escalationData.startTime + _timeUntilDeadline;
    if (block.timestamp >= _deadline) revert ERC20ResolutionModule_VotingPhaseOver();

    // TODO: create an enumerable set-like structure where the index is the address
    //       otherwise if new members are pushed, they can vote with 1 wei for example
    //       and DoS the loading of the array
    votes[_disputeId].push(VoterData({voter: msg.sender, numOfVotes: _numberOfVotes}));

    escalationData[_disputeId].totalVotes += _numberOfVotes;

    _token.safeTransferFrom(msg.sender, address(this), _numberOfVotes);
    emit VoteCast(msg.sender, _disputeId, _numberOfVotes);
  }

  function resolveDispute(bytes32 _disputeId) external onlyOracle {
    // 0. Check disputeId actually exists and that it isnt resolved already
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    if (_dispute.createdAt == 0) revert ERC20ResolutionModule_NonExistentDispute();
    if (_dispute.status != IOracle.DisputeStatus.None) revert ERC20ResolutionModule_AlreadyResolved();

    EscalationData memory _escalationData = escalationData[_disputeId];
    // Check that the dispute is actually escalated
    if (_escalationData.startTime == 0) revert ERC20ResolutionModule_DisputeNotEscalated();

    // 2. Check that voting deadline is over
    (, IERC20 _token, uint256 _minVotesForQuorum, uint256 _timeUntilDeadline) = decodeRequestData(_dispute.requestId);
    uint256 _deadline = _escalationData.startTime + _timeUntilDeadline;
    if (block.timestamp < _deadline) revert ERC20ResolutionModule_OnGoingVotingPhase();

    uint256 _quorumReached = _escalationData.totalVotes >= _minVotesForQuorum ? 1 : 0;

    VoterData[] memory _voterData = votes[_disputeId];

    // 5. Update status
    if (_quorumReached == 1) {
      ORACLE.updateDisputeStatus(_disputeId, IOracle.DisputeStatus.Won);
      emit DisputeResolved(_disputeId, IOracle.DisputeStatus.Won);
    } else {
      ORACLE.updateDisputeStatus(_disputeId, IOracle.DisputeStatus.Lost);
      emit DisputeResolved(_disputeId, IOracle.DisputeStatus.Lost);
    }

    // 6. Return tokens
    for (uint256 _i; _i < _voterData.length;) {
      _token.safeTransfer(_voterData[_i].voter, _voterData[_i].numOfVotes);
      unchecked {
        ++_i;
      }
    }
  }
}
