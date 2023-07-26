// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IBondEscalationResolutionModule} from '../../interfaces/modules/IBondEscalationResolutionModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IBondEscalationAccounting} from '../../interfaces/extensions/IBondEscalationAccounting.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {Module} from '../Module.sol';

contract BondEscalationResolutionModule is Module, IBondEscalationResolutionModule {
  using SafeERC20 for IERC20;

  uint256 public constant BASE = 100;

  mapping(bytes32 _disputeId => EscalationData _escalationData) public escalationData;
  mapping(bytes32 _disputeId => InequalityData _inequalityData) public inequalityData;

  mapping(bytes32 _disputeId => PledgeData[] _pledgeData) public pledgedFor;
  mapping(bytes32 _disputeId => PledgeData[] _pledgeData) public pledgedAgainst;

  constructor(IOracle _oracle) Module(_oracle) {}

  function moduleName() external pure returns (string memory _moduleName) {
    return 'BondEscalationResolutionModule';
  }

  function decodeRequestData(bytes32 _requestId)
    public
    view
    returns (
      IBondEscalationAccounting _accountingExtension,
      IERC20 _token,
      uint256 _percentageDiff,
      uint256 _pledgeThreshold,
      uint256 _timeUntilDeadline,
      uint256 _timeToBreakInequality
    )
  {
    (_accountingExtension, _token, _percentageDiff, _pledgeThreshold, _timeUntilDeadline, _timeToBreakInequality) =
      abi.decode(requestData[_requestId], (IBondEscalationAccounting, IERC20, uint256, uint256, uint256, uint256));
  }

  function startResolution(bytes32 _disputeId) external onlyOracle {
    bytes32 _requestId = ORACLE.getDispute(_disputeId).requestId;
    escalationData[_disputeId].startTime = uint128(block.timestamp);
    emit DisputeEscalated(_disputeId, _requestId);
  }

  function pledgeForDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) external {
    // Cache reused struct
    EscalationData storage _escalationData = escalationData[_disputeId];

    // Revert if dispute not escalated
    if (_escalationData.startTime == 0) revert BondEscalationResolutionModule_NotEscalated();

    InequalityData storage _inequalityData = inequalityData[_disputeId];

    {
      // Get necessary params
      (,,,, uint256 _timeUntilDeadline, uint256 _timeToBreakInequality) = decodeRequestData(_requestId);

      // Calculate deadline
      // TODO: check overflow
      uint256 _pledgingDeadline = _escalationData.startTime + _timeUntilDeadline;

      // Revert if we are in or past the deadline
      if (block.timestamp >= _pledgingDeadline) revert BondEscalationResolutionModule_PledgingPhaseOver();

      // Check
      if (_inequalityData.time != 0 && block.timestamp >= _inequalityData.time + _timeToBreakInequality) {
        revert BondEscalationResolutionModule_MustBeResolved();
      }

      if (_inequalityData.inequalityStatus == InequalityStatus.AgainstTurnToEqualize) {
        revert BondEscalationResolutionModule_AgainstTurnToEqualize();
      }
    }

    uint256 _currentForVotes = _escalationData.pledgesFor;
    uint256 _currentAgainstVotes = _escalationData.pledgesAgainst;

    // Refetching to avoid stack-too-deep
    (IBondEscalationAccounting _accountingExtension, IERC20 _token, uint256 _percentageDiff, uint256 _pledgeThreshold,,)
    = decodeRequestData(_requestId);

    // If minThreshold not reached, or ForTurnToVote, or Equalized allow vote
    if (
      _currentForVotes < _pledgeThreshold && _currentAgainstVotes < _pledgeThreshold
        || _inequalityData.inequalityStatus == InequalityStatus.Equalized
        || _inequalityData.inequalityStatus == InequalityStatus.ForTurnToEqualize
    ) {
      // Optimistically update amount of votes pledged for the dispute
      _escalationData.pledgesFor += _pledgeAmount;

      // Optimistically update amount of votes pledged by the caller
      // TODO: change to a better data structure -- set/dictionary
      pledgedFor[_disputeId].push(PledgeData({pledger: msg.sender, pledges: _pledgeAmount}));

      // Pledge in the accounting extension
      _accountingExtension.pledge(msg.sender, _requestId, _disputeId, _token, _pledgeAmount);

      // Emit event
      emit PledgedForDispute(msg.sender, _requestId, _disputeId, _pledgeAmount);

      // Update InequalityData accordingly
      uint256 _updatedForVotes = _currentForVotes + _pledgeAmount;

      // If the new amount of pledged votes doesn't surpass the threshold, return
      if (
        _currentForVotes < _pledgeThreshold && _currentAgainstVotes < _pledgeThreshold
          && _updatedForVotes < _pledgeThreshold
      ) {
        return;
      }

      uint256 _currentTotalVotes = _currentForVotes + _currentAgainstVotes;

      // TODO: add larger coefficient
      uint256 _currentForVotesPercentage = _updatedForVotes * 100 / _currentTotalVotes;
      uint256 _currentAgainstVotesPercentage = _currentAgainstVotes * 100 / _currentTotalVotes;

      // TODO: check math
      int256 _forPercentageDifference = int256(_currentForVotesPercentage) - int256(_currentAgainstVotesPercentage);
      int256 _againstPercentageDifference = int256(_currentAgainstVotesPercentage) - int256(_currentForVotesPercentage);

      // TODO: safe cast? it should never reach max tho
      int256 _percentageDiffAsInt = int256(_percentageDiff);

      if (
        _currentForVotes < _pledgeThreshold && _currentAgainstVotes < _pledgeThreshold
          && _updatedForVotes >= _pledgeThreshold && _forPercentageDifference < _percentageDiffAsInt
      ) {
        _inequalityData.inequalityStatus = InequalityStatus.Equalized;
        _inequalityData.time = 0;
        return;
      }

      if (_forPercentageDifference >= _percentageDiffAsInt) {
        _inequalityData.inequalityStatus = InequalityStatus.AgainstTurnToEqualize;
        _inequalityData.time = block.timestamp;
        return;
      }

      // If the difference is still below the equalization threshold, leave as ForTurnToEqualize
      if (
        _againstPercentageDifference >= _percentageDiffAsInt
          && _inequalityData.inequalityStatus == InequalityStatus.ForTurnToEqualize
      ) {
        return;
      }

      // If it was the time of the for equalizers to equalize, and they did, reset the timer
      if (
        _againstPercentageDifference < _percentageDiffAsInt
          && _inequalityData.inequalityStatus == InequalityStatus.ForTurnToEqualize
      ) {
        _inequalityData.inequalityStatus = InequalityStatus.Equalized;
        _inequalityData.time = 0;
        return;
      }
    }
  }

  function pledgeAgainstDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) external {
    // Cache reused struct
    EscalationData storage _escalationData = escalationData[_disputeId];

    // Revert if dispute not escalated
    if (_escalationData.startTime == 0) revert BondEscalationResolutionModule_NotEscalated();

    InequalityData storage _inequalityData = inequalityData[_disputeId];
    {
      // Get necessary params
      (,,,, uint256 _timeUntilDeadline, uint256 _timeToBreakInequality) = decodeRequestData(_requestId);

      // Calculate deadline
      // TODO: check overflow
      uint256 _pledgingDeadline = _escalationData.startTime + _timeUntilDeadline;

      // Revert if we are in or past the deadline
      if (block.timestamp >= _pledgingDeadline) revert BondEscalationResolutionModule_PledgingPhaseOver();

      // Check
      if (_inequalityData.time != 0 && block.timestamp >= _inequalityData.time + _timeToBreakInequality) {
        revert BondEscalationResolutionModule_MustBeResolved();
      }

      if (_inequalityData.inequalityStatus == InequalityStatus.ForTurnToEqualize) {
        revert BondEscalationResolutionModule_ForTurnToEqualize();
      }
    }

    uint256 _currentForVotes = _escalationData.pledgesFor;
    uint256 _currentAgainstVotes = _escalationData.pledgesAgainst;

    // Refetching to avoid stack-too-deep
    (IBondEscalationAccounting _accountingExtension, IERC20 _token, uint256 _percentageDiff, uint256 _pledgeThreshold,,)
    = decodeRequestData(_requestId);

    // If minThreshold not reached, allow vote
    if (
      _currentForVotes < _pledgeThreshold && _currentAgainstVotes < _pledgeThreshold
        || _inequalityData.inequalityStatus == InequalityStatus.Equalized
        || _inequalityData.inequalityStatus == InequalityStatus.AgainstTurnToEqualize
    ) {
      // Optimistically update amount of votes pledged for the dispute
      _escalationData.pledgesAgainst += _pledgeAmount;

      // Optimistically update amount of votes pledged by the caller
      pledgedAgainst[_disputeId].push(PledgeData({pledger: msg.sender, pledges: _pledgeAmount}));

      // Pledge in the accounting extension
      _accountingExtension.pledge(msg.sender, _requestId, _disputeId, _token, _pledgeAmount);

      // Emit event
      emit PledgedAgainstDispute(msg.sender, _requestId, _disputeId, _pledgeAmount);

      // Update InequalityData accordingly
      uint256 _updatedAgainstVotes = _currentAgainstVotes + _pledgeAmount;

      // If the new amount of pledged votes doesn't surpass the threshold, return
      if (
        _currentForVotes < _pledgeThreshold && _currentAgainstVotes < _pledgeThreshold
          && _updatedAgainstVotes < _pledgeThreshold
      ) {
        return;
      }

      uint256 _currentTotalVotes = _currentForVotes + _currentAgainstVotes;
      // TODO: add larger coefficient
      uint256 _currentForVotesPercentage = _currentForVotes * 100 / _currentTotalVotes;
      uint256 _currentAgainstVotesPercentage = _updatedAgainstVotes * 100 / _currentTotalVotes;
      // TODO: check math
      int256 _forPercentageDifference = int256(_currentForVotesPercentage) - int256(_currentAgainstVotesPercentage);
      int256 _againstPercentageDifference = int256(_currentAgainstVotesPercentage) - int256(_currentForVotesPercentage);

      // TODO: safe cast? it should never reach max tho
      int256 _percentageDiffAsInt = int256(_percentageDiff);

      if (
        _currentForVotes < _pledgeThreshold && _currentAgainstVotes < _pledgeThreshold
          && _updatedAgainstVotes >= _pledgeThreshold && _againstPercentageDifference < _percentageDiffAsInt
      ) {
        _inequalityData.inequalityStatus = InequalityStatus.Equalized;
        _inequalityData.time = 0;
        return;
      }

      if (_againstPercentageDifference >= _percentageDiffAsInt) {
        _inequalityData.inequalityStatus = InequalityStatus.ForTurnToEqualize;
        _inequalityData.time = block.timestamp;
        return;
      }

      // If the difference is still below the equalization threshold, leave as AgainstTurnToEqualize
      if (
        _forPercentageDifference >= _percentageDiffAsInt
          && _inequalityData.inequalityStatus == InequalityStatus.AgainstTurnToEqualize
      ) {
        return;
      }

      // If it was the time of the for equalizers to equalize, and they did, reset the timer
      if (
        _forPercentageDifference < _percentageDiffAsInt
          && _inequalityData.inequalityStatus == InequalityStatus.AgainstTurnToEqualize
      ) {
        _inequalityData.inequalityStatus = InequalityStatus.Equalized;
        _inequalityData.time = 0;
        return;
      }
    }
  }

  function resolveDispute(bytes32 _disputeId) external onlyOracle {
    // Cache reused struct
    EscalationData storage _escalationData = escalationData[_disputeId];

    // Revert if already resolved
    if (_escalationData.resolution != Resolution.Unresolved) revert BondEscalationResolutionModule_AlreadyResolved();

    // Revert if dispute not escalated
    if (_escalationData.startTime == 0) revert BondEscalationResolutionModule_NotEscalated();

    // Get requestId
    bytes32 _requestId = ORACLE.getDispute(_disputeId).requestId;

    // Get necessary params
    (,,, uint256 _pledgeThreshold, uint256 _timeUntilDeadline, uint256 _timeToBreakInequality) =
      decodeRequestData(_requestId);

    // Cache reused inequality data
    InequalityData storage _inequalityData = inequalityData[_disputeId];

    // TODO: 0 check on .time? I guess it may be necessary due to potential misconfiguration
    // if _timeToBreakInequality > block.timestamp this could be settled instantly
    uint256 _inequalityTimerDeadline = _inequalityData.time + _timeToBreakInequality;

    // Calculate deadline
    // TODO: check overflow
    uint256 _pledgingDeadline = _escalationData.startTime + _timeUntilDeadline;

    // Revert if we have not yet reached the deadline and the timer has not passed
    // TODO: double check this when fresh - This is wrong because _inequalityTimerDeadline may never be 0, as that would require _timeToBreakInequality to be 0
    //       the actual check should be something along the lines of _inequalityData.time != 0 not _inequalityTimerDeadline. check though
    if (
      block.timestamp < _pledgingDeadline && _inequalityTimerDeadline != 0 && block.timestamp < _inequalityTimerDeadline
    ) revert BondEscalationResolutionModule_PledgingPhaseNotOver();

    // TODO: cache variables
    if (
      _escalationData.pledgesFor < _pledgeThreshold && _escalationData.pledgesAgainst < _pledgeThreshold
        || _escalationData.pledgesFor == _escalationData.pledgesAgainst
    ) {
      _escalationData.resolution = Resolution.NoResolution;
      // TODO:
      // ORACLE.updateDisputeStatus(_disputeId, IOracle.DisputeStatus.NoResolution);
      // emit DisputeResolved(_disputeId, IOracle.DisputeStatus.NoResolution);
      // return;
    }

    if (_escalationData.pledgesFor > _escalationData.pledgesAgainst) {
      _escalationData.resolution = Resolution.DisputerWon;
      ORACLE.updateDisputeStatus(_disputeId, IOracle.DisputeStatus.Won);
      emit DisputeResolved(_disputeId, IOracle.DisputeStatus.Won);
      return;
    }

    if (_escalationData.pledgesAgainst > _escalationData.pledgesFor) {
      _escalationData.resolution = Resolution.DisputerLost;
      ORACLE.updateDisputeStatus(_disputeId, IOracle.DisputeStatus.Lost);
      emit DisputeResolved(_disputeId, IOracle.DisputeStatus.Lost);
      return;
    }
  }

  // TODO: Note: It's possible that because we are using the dispute module and the resolution module with
  // the same extension, that the balance for this dispute increases due to both using them.
  // it's extremely important to be careful with math precision here to not DoS the accountancy settling
  function settleAccountancy(bytes32 _requestId, bytes32 _disputeId) external {
    EscalationData storage _escalationData = escalationData[_disputeId];

    // Revert if not resolved
    if (_escalationData.resolution == Resolution.Unresolved) revert BondEscalationResolutionModule_NotResolved();

    uint256 _pledgesForLength = pledgedFor[_disputeId].length;
    uint256 _pledgesAgainstLength = pledgedAgainst[_disputeId].length;

    (IBondEscalationAccounting _accountingExtension, IERC20 _token,,,,) = decodeRequestData(_requestId);

    if (_escalationData.resolution == Resolution.DisputerWon) {
      // TODO: check math -- add coefficient
      uint256 _amountPerPledger = _escalationData.pledgesAgainst / _pledgesForLength;
      // TODO: lmao improve this with enumerable set or some thist
      address[] memory _winningPledgers = new address[](_pledgesForLength);
      for (uint256 _i; _i < _pledgesForLength;) {
        _winningPledgers[_i] = pledgedFor[_disputeId][_i].pledger;
        unchecked {
          ++_i;
        }
      }
      _accountingExtension.payWinningPledgers(_requestId, _disputeId, _winningPledgers, _token, _amountPerPledger);
      // TODO: [OPO-89] emit event
      return;
    }

    if (_escalationData.resolution == Resolution.DisputerLost) {
      // TODO: check math -- add coefficient
      uint256 _amountPerPledger = _escalationData.pledgesFor / _pledgesAgainstLength;
      // TODO: lmao improve this with enumerable set or some thist
      address[] memory _winningPledgers = new address[](_pledgesAgainstLength);
      for (uint256 _i; _i < _pledgesAgainstLength;) {
        _winningPledgers[_i] = pledgedAgainst[_disputeId][_i].pledger;
        unchecked {
          ++_i;
        }
      }
      _accountingExtension.payWinningPledgers(_requestId, _disputeId, _winningPledgers, _token, _amountPerPledger);
      // TODO: [OPO-89] emit event
      return;
    }

    // TODO: add NoResolution release path
  }

  function fetchPledgeDataFor(bytes32 _disputeId) external view returns (PledgeData[] memory _pledgeData) {
    PledgeData[] memory _pledgeDataCache = pledgedFor[_disputeId];
    uint256 _pledgedForLength = _pledgeDataCache.length;
    _pledgeData = new PledgeData[](_pledgedForLength);

    for (uint256 _i; _i < _pledgedForLength;) {
      _pledgeData[_i] = _pledgeDataCache[_i];
      unchecked {
        ++_i;
      }
    }
  }

  function fetchPledgeDataAgainst(bytes32 _disputeId) external view returns (PledgeData[] memory _pledgeData) {
    PledgeData[] memory _pledgeDataCache = pledgedAgainst[_disputeId];
    uint256 _pledgedAgainstLength = _pledgeDataCache.length;
    _pledgeData = new PledgeData[](_pledgedAgainstLength);

    for (uint256 _i; _i < _pledgedAgainstLength;) {
      _pledgeData[_i] = _pledgeDataCache[_i];
      unchecked {
        ++_i;
      }
    }
  }
}
