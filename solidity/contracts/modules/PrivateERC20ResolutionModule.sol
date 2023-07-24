// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IPrivateERC20ResolutionModule} from '../../interfaces/modules/IPrivateERC20ResolutionModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IAccountingExtension} from '../../interfaces/extensions/IAccountingExtension.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {Module} from '../Module.sol';

contract PrivateERC20ResolutionModule is Module, IPrivateERC20ResolutionModule {
  using SafeERC20 for IERC20;

  uint256 public constant BASE = 100;

  mapping(bytes32 _disputeId => EscalationData _escalationData) public escalationData;
  mapping(bytes32 _disputeId => VoterData[]) public votes;
  mapping(bytes32 _disputeId => uint256 _numOfVotes) public totalNumberOfVotes;
  mapping(bytes32 _disputeId => mapping(address _voter => bytes32 _commitment)) public commitments;

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
      uint256 _disputerBondSize,
      uint256 _minQuorum,
      uint256 _commitingTimeWindow,
      uint256 _revealingTimeWindow
    )
  {
    (_accountingExtension, _token, _disputerBondSize, _minQuorum, _commitingTimeWindow, _revealingTimeWindow) =
      _decodeRequestData(requestData[_requestId]);
  }

  function _decodeRequestData(bytes memory _data)
    internal
    pure
    returns (
      IAccountingExtension _accountingExtension,
      IERC20 _token,
      uint256 _disputerBondSize,
      uint256 _minQuorum,
      uint256 _commitingTimeWindow,
      uint256 _revealingTimeWindow
    )
  {
    (_accountingExtension, _token, _disputerBondSize, _minQuorum, _commitingTimeWindow, _revealingTimeWindow) =
      abi.decode(_data, (IAccountingExtension, IERC20, uint256, uint256, uint256, uint256));
  }

  function startResolution(bytes32 _disputeId) external onlyOracle {
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);

    (IAccountingExtension _accounting, IERC20 _token, uint256 _disputerBondSize,,,) =
      decodeRequestData(_dispute.requestId);

    escalationData[_disputeId].startTime = uint128(block.timestamp);

    if (_disputerBondSize != 0) {
      // seize disputer bond until resolution - this allows for voters not having to call deposit in the accounting extension
      // TODO: should another event be emitted with disputerBond?
      _accounting.pay(_dispute.requestId, _dispute.disputer, address(this), _token, _disputerBondSize);
      _accounting.withdraw(_token, _disputerBondSize);
      escalationData[_disputeId].disputerBond = _disputerBondSize;
    }

    emit CommitingPhaseStarted(uint128(block.timestamp), _disputeId);
  }

  // commit vote in favor of dispute
  function commitVote(bytes32 _requestId, bytes32 _disputeId, bytes32 _commitment) public {
    /*
      1. Check that the disputeId is Escalated - TODO
      2. Check that the commiting deadline is not over
      3. Check that the user did not provide an empty commitment
      4. Emit VoteCommited event

      @dev we are allowing users to commit multiple times, changing the amount of votes being commited
    */
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    if (_dispute.createdAt == 0) revert PrivateERC20ResolutionModule_NonExistentDispute();

    EscalationData memory _escalationData = escalationData[_disputeId];

    if (_escalationData.startTime == 0) revert PrivateERC20ResolutionModule_DisputeNotEscalated();

    (,,,, uint256 _commitingTimeWindow,) = decodeRequestData(_requestId);
    uint256 _deadline = _escalationData.startTime + _commitingTimeWindow;
    if (block.timestamp >= _deadline) revert PrivateERC20ResolutionModule_CommitingPhaseOver();

    if (_commitment == bytes32('')) revert PrivateERC20ResolutionModule_EmptyCommitment();
    commitments[_disputeId][msg.sender] = _commitment;

    emit VoteCommited(msg.sender, _disputeId, _commitment);
  }

  function revealVote(bytes32 _requestId, bytes32 _disputeId, uint256 _numberOfVotes, bytes32 _salt) public {
    /*
      1. Check that the commiting deadline is not over
      2. Check that the user did not provide an empty commitment
      3. Emit VoteCommited event

      @dev we are allowing users to commit multiple times, changing the amount of votes being commited
    */
    EscalationData memory _escalationData = escalationData[_disputeId];
    if (_escalationData.startTime == 0) revert PrivateERC20ResolutionModule_DisputeNotEscalated();

    (, IERC20 _token,,, uint256 _commitingTimeWindow, uint256 _revealingTimeWindow) = decodeRequestData(_requestId);
    (uint256 _revealStartTime, uint256 _revealEndTime) = (
      _escalationData.startTime + _commitingTimeWindow,
      _escalationData.startTime + _commitingTimeWindow + _revealingTimeWindow
    );
    if (block.timestamp < _revealStartTime) revert PrivateERC20ResolutionModule_OnGoingCommitingPhase();
    if (block.timestamp >= _revealEndTime) revert PrivateERC20ResolutionModule_RevealingPhaseOver();

    if (commitments[_disputeId][msg.sender] != keccak256(abi.encode(msg.sender, _disputeId, _numberOfVotes, _salt))) {
      revert PrivateERC20ResolutionModule_WrongRevealData();
    }
    delete commitments[_disputeId][msg.sender];

    votes[_disputeId].push(VoterData({voter: msg.sender, numOfVotes: _numberOfVotes}));
    escalationData[_disputeId].totalVotes += _numberOfVotes;

    _token.safeTransferFrom(msg.sender, address(this), _numberOfVotes);

    emit VoteRevealed(msg.sender, _disputeId, _numberOfVotes);
  }

  function resolveDispute(bytes32 _disputeId) external onlyOracle {
    // 0. Check that the disputeId actually exists
    IOracle.Dispute memory _dispute = ORACLE.getDispute(_disputeId);
    if (_dispute.createdAt == 0) revert PrivateERC20ResolutionModule_NonExistentDispute();

    EscalationData memory _escalationData = escalationData[_disputeId];

    // Check that the dispute is actually escalated
    if (_escalationData.startTime == 0) revert PrivateERC20ResolutionModule_DisputeNotEscalated();

    // 2. Check that voting deadline is over
    (
      IAccountingExtension _accounting,
      IERC20 _token,
      ,
      uint256 _minQuorum,
      uint256 _commitingTimeWindow,
      uint256 _revealingTimeWindow
    ) = decodeRequestData(_dispute.requestId);
    if (block.timestamp < _escalationData.startTime + _commitingTimeWindow) {
      revert PrivateERC20ResolutionModule_OnGoingCommitingPhase();
    }
    if (block.timestamp < _escalationData.startTime + _commitingTimeWindow + _revealingTimeWindow) {
      revert PrivateERC20ResolutionModule_OnGoingRevealingPhase();
    }

    // 3. Check quorum - TODO: check if this is precise- think if using totalSupply makes sense, perhaps minQuorum can be
    // min amount of tokens required instead of a percentage
    // not sure if safe but the actual formula is _token.totalSupply() * _minQuorum * BASE(100) / 100 so base disappears
    // i guess with a shit token someone could front run this call and increase totalSupply enough for this to fail
    uint256 _numVotesForQuorum = _token.totalSupply() * _minQuorum;
    uint256 _quorumReached = _escalationData.totalVotes * BASE >= _numVotesForQuorum ? 1 : 0;

    // 4. Store result
    escalationData[_disputeId].results = _quorumReached == 1 ? 1 : 2;

    VoterData[] memory _voterData = votes[_disputeId];

    uint256 _disputerBond = _escalationData.disputerBond;
    uint256 _amountToPay;
    // 5. Pay and Release
    if (_quorumReached == 1) {
      for (uint256 _i; _i < _voterData.length;) {
        // TODO: check math -- remember _numVotesForQuorum is escalated
        _amountToPay = _disputerBond == 0
          ? _voterData[_i].numOfVotes
          : _voterData[_i].numOfVotes + (_voterData[_i].numOfVotes * _numVotesForQuorum / _disputerBond * BASE);
        _token.safeTransfer(_voterData[_i].voter, _amountToPay);
        unchecked {
          ++_i;
        }
      }
    } else {
      // This also releases the disputer's bond
      if (_disputerBond != 0) {
        _accounting.pay(_dispute.requestId, address(this), _dispute.disputer, _token, _disputerBond);
      }
      for (uint256 _i; _i < _voterData.length;) {
        _token.safeTransfer(_voterData[_i].voter, _voterData[_i].numOfVotes);
        unchecked {
          ++_i;
        }
      }
    }

    if (_disputerBond != 0) {
      escalationData[_disputeId].disputerBond = 0;
    }

    emit DisputeResolved(_disputeId);
  }

  function computeCommitment(
    bytes32 _disputeId,
    uint256 _numberOfVotes,
    bytes32 _salt
  ) external view returns (bytes32 _commitment) {
    _commitment = keccak256(abi.encode(msg.sender, _disputeId, _numberOfVotes, _salt));
  }
}
