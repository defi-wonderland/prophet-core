// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IPrivateERC20ResolutionModule} from '../../interfaces/modules/IPrivateERC20ResolutionModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {Module} from '../Module.sol';

contract PrivateERC20ResolutionModule is Module, IPrivateERC20ResolutionModule {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  // todo: this storage layout must be super optimizable. many disputeId mappings
  mapping(bytes32 _disputeId => EscalationData _escalationData) public escalationData;
  mapping(bytes32 _disputeId => mapping(address _voter => VoterData)) public _votersData;
  mapping(bytes32 _disputeId => uint256 _numOfVotes) public totalNumberOfVotes;
  mapping(bytes32 _disputeId => EnumerableSet.AddressSet _votersSet) internal _voters;

  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() external pure returns (string memory _moduleName) {
    return 'PrivateERC20ResolutionModule';
  }

  function decodeRequestData(bytes32 _requestId)
    public
    view
    returns (
      IAccountingExtension _accountingExtension,
      IERC20 _token,
      uint256 _minVotesForQuorum,
      uint256 _commitingTimeWindow,
      uint256 _revealingTimeWindow
    )
  {
    (_accountingExtension, _token, _minVotesForQuorum, _commitingTimeWindow, _revealingTimeWindow) =
      abi.decode(requestData[_requestId], (IAccountingExtension, IERC20, uint256, uint256, uint256));
  }

  function startResolution(bytes32 _disputeId) external onlyOracle {
    escalationData[_disputeId].startTime = block.timestamp;
    emit CommitingPhaseStarted(block.timestamp, _disputeId);
  }

  function commitVote(bytes32 _requestId, bytes32 _disputeId, bytes32 _commitment) public {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    if (_dispute.createdAt == 0) revert PrivateERC20ResolutionModule_NonExistentDispute();
    if (_dispute.status != IOracle.DisputeStatus.None) revert PrivateERC20ResolutionModule_AlreadyResolved();

    uint256 _startTime = escalationData[_disputeId].startTime;
    if (_startTime == 0) revert PrivateERC20ResolutionModule_DisputeNotEscalated();

    (,,, uint256 _commitingTimeWindow,) = decodeRequestData(_requestId);
    uint256 _commitingDeadline = _startTime + _commitingTimeWindow;
    if (block.timestamp >= _commitingDeadline) revert PrivateERC20ResolutionModule_CommitingPhaseOver();

    if (_commitment == bytes32('')) revert PrivateERC20ResolutionModule_EmptyCommitment();
    _votersData[_disputeId][msg.sender] = VoterData({numOfVotes: 0, commitment: _commitment});

    emit VoteCommited(msg.sender, _disputeId, _commitment);
  }

  function revealVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes, bytes32 _salt) public {
    EscalationData memory _escalationData = escalationData[_disputeId];
    if (_escalationData.startTime == 0) revert PrivateERC20ResolutionModule_DisputeNotEscalated();

    (, IERC20 _token,, uint256 _commitingTimeWindow, uint256 _revealingTimeWindow) = decodeRequestData(_requestId);
    (uint256 _revealStartTime, uint256 _revealEndTime) = (
      _escalationData.startTime + _commitingTimeWindow,
      _escalationData.startTime + _commitingTimeWindow + _revealingTimeWindow
    );
    if (block.timestamp <= _revealStartTime) revert PrivateERC20ResolutionModule_OnGoingCommitingPhase();
    if (block.timestamp >= _revealEndTime) revert PrivateERC20ResolutionModule_RevealingPhaseOver();

    VoterData storage _voterData = _votersData[_disputeId][msg.sender];

    if (_voterData.commitment != keccak256(abi.encode(msg.sender, _disputeId, _numberOfVotes, _salt))) {
      revert PrivateERC20ResolutionModule_WrongRevealData();
    }

    _voterData.numOfVotes = _numberOfVotes;
    _voters[_disputeId].add(msg.sender);
    escalationData[_disputeId].totalVotes += _numberOfVotes;

    _token.safeTransferFrom(msg.sender, address(this), _numberOfVotes);

    emit VoteRevealed(msg.sender, _disputeId, _numberOfVotes);
  }

  function resolveDispute(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    if (_dispute.createdAt == 0) revert PrivateERC20ResolutionModule_NonExistentDispute();
    if (_dispute.status != IOracle.DisputeStatus.None) revert PrivateERC20ResolutionModule_AlreadyResolved();

    EscalationData memory _escalationData = escalationData[_disputeId];
    if (_escalationData.startTime == 0) revert PrivateERC20ResolutionModule_DisputeNotEscalated();

    (, IERC20 _token, uint256 _minVotesForQuorum, uint256 _commitingTimeWindow, uint256 _revealingTimeWindow) =
      decodeRequestData(_dispute.requestId);
    if (block.timestamp < _escalationData.startTime + _commitingTimeWindow) {
      revert PrivateERC20ResolutionModule_OnGoingCommitingPhase();
    }
    if (block.timestamp < _escalationData.startTime + _commitingTimeWindow + _revealingTimeWindow) {
      revert PrivateERC20ResolutionModule_OnGoingRevealingPhase();
    }

    uint256 _quorumReached = _escalationData.totalVotes >= _minVotesForQuorum ? 1 : 0;

    address[] memory __voters = _voters[_disputeId].values();

    if (_quorumReached == 1) {
      ORACLE.updateDisputeStatus(_disputeId, IOracle.DisputeStatus.Won);
      emit DisputeResolved(_disputeId, IOracle.DisputeStatus.Won);
    } else {
      ORACLE.updateDisputeStatus(_disputeId, IOracle.DisputeStatus.Lost);
      emit DisputeResolved(_disputeId, IOracle.DisputeStatus.Lost);
    }

    uint256 _length = __voters.length;
    for (uint256 _i; _i < _length;) {
      _token.safeTransfer(__voters[_i], _votersData[_disputeId][__voters[_i]].numOfVotes);
      unchecked {
        ++_i;
      }
    }
  }

  function computeCommitment(
    bytes32 _disputeId,
    uint256 _numberOfVotes,
    bytes32 _salt
  ) external view returns (bytes32 _commitment) {
    _commitment = keccak256(abi.encode(msg.sender, _disputeId, _numberOfVotes, _salt));
  }
}
