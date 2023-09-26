// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IPrivateERC20ResolutionModule} from '../../interfaces/modules/IPrivateERC20ResolutionModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {Module} from '../Module.sol';

contract PrivateERC20ResolutionModule is Module, IPrivateERC20ResolutionModule {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @inheritdoc IPrivateERC20ResolutionModule
  mapping(bytes32 _disputeId => EscalationData _escalationData) public escalationData;
  /**
   * @notice The data of the voters for a given dispute
   */
  mapping(bytes32 _disputeId => mapping(address _voter => VoterData)) internal _votersData;
  /**
   * @notice The voters addresses for a given dispute
   */
  mapping(bytes32 _disputeId => EnumerableSet.AddressSet _votersSet) internal _voters;

  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() external pure returns (string memory _moduleName) {
    return 'PrivateERC20ResolutionModule';
  }

  /// @inheritdoc IPrivateERC20ResolutionModule
  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {
    _params = abi.decode(requestData[_requestId], (RequestParameters));
  }

  /// @inheritdoc IPrivateERC20ResolutionModule
  function startResolution(bytes32 _disputeId) external onlyOracle {
    escalationData[_disputeId].startTime = block.timestamp;
    emit CommittingPhaseStarted(block.timestamp, _disputeId);
  }

  /// @inheritdoc IPrivateERC20ResolutionModule
  function commitVote(bytes32 _requestId, bytes32 _disputeId, bytes32 _commitment) public {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    if (_dispute.createdAt == 0) revert PrivateERC20ResolutionModule_NonExistentDispute();
    if (_dispute.status != IOracle.DisputeStatus.None) revert PrivateERC20ResolutionModule_AlreadyResolved();

    uint256 _startTime = escalationData[_disputeId].startTime;
    if (_startTime == 0) revert PrivateERC20ResolutionModule_DisputeNotEscalated();

    RequestParameters memory _params = decodeRequestData(_requestId);
    uint256 _committingDeadline = _startTime + _params.committingTimeWindow;
    if (block.timestamp >= _committingDeadline) revert PrivateERC20ResolutionModule_CommittingPhaseOver();

    if (_commitment == bytes32('')) revert PrivateERC20ResolutionModule_EmptyCommitment();
    _votersData[_disputeId][msg.sender] = VoterData({numOfVotes: 0, commitment: _commitment});

    emit VoteCommitted(msg.sender, _disputeId, _commitment);
  }

  /// @inheritdoc IPrivateERC20ResolutionModule
  function revealVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes, bytes32 _salt) public {
    EscalationData memory _escalationData = escalationData[_disputeId];
    if (_escalationData.startTime == 0) revert PrivateERC20ResolutionModule_DisputeNotEscalated();

    RequestParameters memory _params = decodeRequestData(_requestId);
    (uint256 _revealStartTime, uint256 _revealEndTime) = (
      _escalationData.startTime + _params.committingTimeWindow,
      _escalationData.startTime + _params.committingTimeWindow + _params.revealingTimeWindow
    );
    if (block.timestamp <= _revealStartTime) revert PrivateERC20ResolutionModule_OnGoingCommittingPhase();
    if (block.timestamp > _revealEndTime) revert PrivateERC20ResolutionModule_RevealingPhaseOver();

    VoterData storage _voterData = _votersData[_disputeId][msg.sender];

    if (_voterData.commitment != keccak256(abi.encode(msg.sender, _disputeId, _numberOfVotes, _salt))) {
      revert PrivateERC20ResolutionModule_WrongRevealData();
    }

    _voterData.numOfVotes = _numberOfVotes;
    _voterData.commitment = bytes32('');
    _voters[_disputeId].add(msg.sender);
    escalationData[_disputeId].totalVotes += _numberOfVotes;

    _params.votingToken.safeTransferFrom(msg.sender, address(this), _numberOfVotes);

    emit VoteRevealed(msg.sender, _disputeId, _numberOfVotes);
  }

  /// @inheritdoc IPrivateERC20ResolutionModule
  function resolveDispute(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    if (_dispute.createdAt == 0) revert PrivateERC20ResolutionModule_NonExistentDispute();
    if (_dispute.status != IOracle.DisputeStatus.None) revert PrivateERC20ResolutionModule_AlreadyResolved();

    EscalationData memory _escalationData = escalationData[_disputeId];
    if (_escalationData.startTime == 0) revert PrivateERC20ResolutionModule_DisputeNotEscalated();

    RequestParameters memory _params = decodeRequestData(_dispute.requestId);

    if (block.timestamp < _escalationData.startTime + _params.committingTimeWindow) {
      revert PrivateERC20ResolutionModule_OnGoingCommittingPhase();
    }
    if (block.timestamp < _escalationData.startTime + _params.committingTimeWindow + _params.revealingTimeWindow) {
      revert PrivateERC20ResolutionModule_OnGoingRevealingPhase();
    }

    uint256 _quorumReached = _escalationData.totalVotes >= _params.minVotesForQuorum ? 1 : 0;

    address[] memory __voters = _voters[_disputeId].values();

    if (_quorumReached == 1) {
      ORACLE.updateDisputeStatus(_disputeId, IOracle.DisputeStatus.Won);
      emit DisputeResolved(_dispute.requestId, _disputeId, IOracle.DisputeStatus.Won);
    } else {
      ORACLE.updateDisputeStatus(_disputeId, IOracle.DisputeStatus.Lost);
      emit DisputeResolved(_dispute.requestId, _disputeId, IOracle.DisputeStatus.Lost);
    }

    uint256 _length = __voters.length;
    for (uint256 _i; _i < _length;) {
      _params.votingToken.safeTransfer(__voters[_i], _votersData[_disputeId][__voters[_i]].numOfVotes);
      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IPrivateERC20ResolutionModule
  function computeCommitment(
    bytes32 _disputeId,
    uint256 _numberOfVotes,
    bytes32 _salt
  ) external view returns (bytes32 _commitment) {
    _commitment = keccak256(abi.encode(msg.sender, _disputeId, _numberOfVotes, _salt));
  }
}
