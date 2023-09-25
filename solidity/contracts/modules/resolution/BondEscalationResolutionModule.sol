// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {FixedPointMathLib} from 'solmate/utils/FixedPointMathLib.sol';

import {
  IBondEscalationResolutionModule,
  IResolutionModule
} from '../../../interfaces/modules/resolution/IBondEscalationResolutionModule.sol';
import {IOracle} from '../../../interfaces/IOracle.sol';
import {IBondEscalationAccounting} from '../../../interfaces/extensions/IBondEscalationAccounting.sol';

import {Module, IModule} from '../../Module.sol';

contract BondEscalationResolutionModule is Module, IBondEscalationResolutionModule {
  using SafeERC20 for IERC20;

  /// @inheritdoc IBondEscalationResolutionModule
  uint256 public constant BASE = 1e18;

  /// @inheritdoc IBondEscalationResolutionModule
  mapping(bytes32 _disputeId => EscalationData _escalationData) public escalationData;

  /// @inheritdoc IBondEscalationResolutionModule
  mapping(bytes32 _disputeId => InequalityData _inequalityData) public inequalityData;

  /// @inheritdoc IBondEscalationResolutionModule
  mapping(bytes32 _disputeId => mapping(address _pledger => uint256 pledges)) public pledgesForDispute;

  /// @inheritdoc IBondEscalationResolutionModule
  mapping(bytes32 _disputeId => mapping(address _pledger => uint256 pledges)) public pledgesAgainstDispute;

  constructor(IOracle _oracle) Module(_oracle) {}

  /// @inheritdoc IModule
  function moduleName() external pure returns (string memory _moduleName) {
    return 'BondEscalationResolutionModule';
  }

  /// @inheritdoc IBondEscalationResolutionModule
  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {
    _params = abi.decode(requestData[_requestId], (RequestParameters));
  }

  /// @inheritdoc IResolutionModule
  function startResolution(bytes32 _disputeId) external onlyOracle {
    bytes32 _requestId = ORACLE.getDispute(_disputeId).requestId;
    escalationData[_disputeId].startTime = uint128(block.timestamp);
    emit ResolutionStarted(_requestId, _disputeId);
  }

  /// @inheritdoc IBondEscalationResolutionModule
  function pledgeForDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) external {
    EscalationData storage _escalationData = escalationData[_disputeId];

    if (_escalationData.startTime == 0) revert BondEscalationResolutionModule_NotEscalated();

    InequalityData storage _inequalityData = inequalityData[_disputeId];

    RequestParameters memory _params = decodeRequestData(_requestId);

    {
      uint256 _pledgingDeadline = _escalationData.startTime + _params.timeUntilDeadline;

      if (block.timestamp >= _pledgingDeadline) revert BondEscalationResolutionModule_PledgingPhaseOver();

      // Revert if the inequality timer has passed
      if (_inequalityData.time != 0 && block.timestamp >= _inequalityData.time + _params.timeToBreakInequality) {
        revert BondEscalationResolutionModule_MustBeResolved();
      }

      if (_inequalityData.inequalityStatus == InequalityStatus.AgainstTurnToEqualize) {
        revert BondEscalationResolutionModule_AgainstTurnToEqualize();
      }
    }

    _escalationData.pledgesFor += _pledgeAmount;
    pledgesForDispute[_disputeId][msg.sender] += _pledgeAmount;

    uint256 _updatedTotalVotes = _escalationData.pledgesFor + _escalationData.pledgesAgainst;

    _params.accountingExtension.pledge({
      _pledger: msg.sender,
      _requestId: _requestId,
      _disputeId: _disputeId,
      _token: _params.bondToken,
      _amount: _pledgeAmount
    });
    emit PledgedForDispute(msg.sender, _requestId, _disputeId, _pledgeAmount);

    if (_updatedTotalVotes >= _params.pledgeThreshold) {
      uint256 _updatedForVotes = _escalationData.pledgesFor;
      uint256 _againstVotes = _escalationData.pledgesAgainst;

      uint256 _newForVotesPercentage = FixedPointMathLib.mulDivDown(_updatedForVotes, BASE, _updatedTotalVotes);
      uint256 _againstVotesPercentage = FixedPointMathLib.mulDivDown(_againstVotes, BASE, _updatedTotalVotes);

      int256 _forPercentageDifference = int256(_newForVotesPercentage) - int256(_againstVotesPercentage);
      int256 _againstPercentageDifference = int256(_againstVotesPercentage) - int256(_newForVotesPercentage);

      int256 _scaledPercentageDiffAsInt = int256(_params.percentageDiff * BASE / 100);

      if (_againstPercentageDifference >= _scaledPercentageDiffAsInt) return;

      if (_forPercentageDifference >= _scaledPercentageDiffAsInt) {
        _inequalityData.inequalityStatus = InequalityStatus.AgainstTurnToEqualize;
        _inequalityData.time = block.timestamp;
      } else if (_inequalityData.inequalityStatus == InequalityStatus.ForTurnToEqualize) {
        // At this point, both _forPercentageDiff and _againstPercentageDiff are < _percentageDiff
        _inequalityData.inequalityStatus = InequalityStatus.Equalized;
        _inequalityData.time = 0;
      }
    }
  }

  /// @inheritdoc IBondEscalationResolutionModule
  function pledgeAgainstDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) external {
    EscalationData storage _escalationData = escalationData[_disputeId];

    if (_escalationData.startTime == 0) revert BondEscalationResolutionModule_NotEscalated();

    InequalityData storage _inequalityData = inequalityData[_disputeId];

    RequestParameters memory _params = decodeRequestData(_requestId);

    {
      uint256 _pledgingDeadline = _escalationData.startTime + _params.timeUntilDeadline;

      if (block.timestamp >= _pledgingDeadline) revert BondEscalationResolutionModule_PledgingPhaseOver();

      // Revert if the inequality timer has passed
      if (_inequalityData.time != 0 && block.timestamp >= _inequalityData.time + _params.timeToBreakInequality) {
        revert BondEscalationResolutionModule_MustBeResolved();
      }

      if (_inequalityData.inequalityStatus == InequalityStatus.ForTurnToEqualize) {
        revert BondEscalationResolutionModule_ForTurnToEqualize();
      }
    }

    _escalationData.pledgesAgainst += _pledgeAmount;
    pledgesAgainstDispute[_disputeId][msg.sender] += _pledgeAmount;

    uint256 _updatedTotalVotes = _escalationData.pledgesFor + _escalationData.pledgesAgainst;

    _params.accountingExtension.pledge({
      _pledger: msg.sender,
      _requestId: _requestId,
      _disputeId: _disputeId,
      _token: _params.bondToken,
      _amount: _pledgeAmount
    });
    emit PledgedAgainstDispute(msg.sender, _requestId, _disputeId, _pledgeAmount);

    if (_updatedTotalVotes >= _params.pledgeThreshold) {
      uint256 _updatedAgainstVotes = _escalationData.pledgesAgainst;
      uint256 _forVotes = _escalationData.pledgesFor;

      uint256 _forVotesPercentage = FixedPointMathLib.mulDivDown(_forVotes, BASE, _updatedTotalVotes);
      uint256 _newAgainstVotesPercentage = FixedPointMathLib.mulDivDown(_updatedAgainstVotes, BASE, _updatedTotalVotes);
      int256 _forPercentageDifference = int256(_forVotesPercentage) - int256(_newAgainstVotesPercentage);
      int256 _againstPercentageDifference = int256(_newAgainstVotesPercentage) - int256(_forVotesPercentage);

      int256 _scaledPercentageDiffAsInt = int256(_params.percentageDiff * BASE / 100);

      if (_forPercentageDifference >= _scaledPercentageDiffAsInt) return;

      if (_againstPercentageDifference >= _scaledPercentageDiffAsInt) {
        _inequalityData.inequalityStatus = InequalityStatus.ForTurnToEqualize;
        _inequalityData.time = block.timestamp;
      } else if (_inequalityData.inequalityStatus == InequalityStatus.AgainstTurnToEqualize) {
        // At this point, both _forPercentageDiff and _againstPercentageDiff are < _percentageDiff
        _inequalityData.inequalityStatus = InequalityStatus.Equalized;
        _inequalityData.time = 0;
      }
    }
  }

  /// @inheritdoc IResolutionModule
  function resolveDispute(bytes32 _disputeId) external onlyOracle {
    EscalationData storage _escalationData = escalationData[_disputeId];

    if (_escalationData.resolution != Resolution.Unresolved) revert BondEscalationResolutionModule_AlreadyResolved();
    if (_escalationData.startTime == 0) revert BondEscalationResolutionModule_NotEscalated();

    bytes32 _requestId = ORACLE.getDispute(_disputeId).requestId;

    RequestParameters memory _params = decodeRequestData(_requestId);

    InequalityData storage _inequalityData = inequalityData[_disputeId];

    uint256 _inequalityTimerDeadline = _inequalityData.time + _params.timeToBreakInequality;

    uint256 _pledgingDeadline = _escalationData.startTime + _params.timeUntilDeadline;

    // Revert if we have not yet reached the deadline and the timer has not passed
    if (block.timestamp < _pledgingDeadline && block.timestamp < _inequalityTimerDeadline) {
      revert BondEscalationResolutionModule_PledgingPhaseNotOver();
    }

    uint256 _pledgesFor = _escalationData.pledgesFor;
    uint256 _pledgesAgainst = _escalationData.pledgesAgainst;
    uint256 _totalPledges = _pledgesFor + _pledgesAgainst;

    IOracle.DisputeStatus _disputeStatus;

    if (_totalPledges < _params.pledgeThreshold || _pledgesFor == _pledgesAgainst) {
      _escalationData.resolution = Resolution.NoResolution;
      _disputeStatus = IOracle.DisputeStatus.NoResolution;
    } else if (_pledgesFor > _pledgesAgainst) {
      _escalationData.resolution = Resolution.DisputerWon;
      _disputeStatus = IOracle.DisputeStatus.Won;
    } else if (_pledgesAgainst > _pledgesFor) {
      _escalationData.resolution = Resolution.DisputerLost;
      _disputeStatus = IOracle.DisputeStatus.Lost;
    }

    ORACLE.updateDisputeStatus(_disputeId, _disputeStatus);
    emit DisputeResolved(_requestId, _disputeId, _disputeStatus);
  }

  /// @inheritdoc IBondEscalationResolutionModule
  function claimPledge(bytes32 _requestId, bytes32 _disputeId) external {
    EscalationData storage _escalationData = escalationData[_disputeId];

    if (_escalationData.resolution == Resolution.Unresolved) revert BondEscalationResolutionModule_NotResolved();

    RequestParameters memory _params = decodeRequestData(_requestId);
    uint256 _pledgerBalanceBefore;
    uint256 _pledgerProportion;
    uint256 _amountToRelease;
    uint256 _reward;

    if (_escalationData.resolution == Resolution.DisputerWon) {
      _pledgerBalanceBefore = pledgesForDispute[_disputeId][msg.sender];
      pledgesForDispute[_disputeId][msg.sender] -= _pledgerBalanceBefore;

      _pledgerProportion = FixedPointMathLib.mulDivDown(_pledgerBalanceBefore, BASE, _escalationData.pledgesFor);
      _reward = FixedPointMathLib.mulDivDown(_escalationData.pledgesAgainst, _pledgerProportion, BASE);
      _amountToRelease = _reward + _pledgerBalanceBefore;
      _params.accountingExtension.releasePledge({
        _requestId: _requestId,
        _disputeId: _disputeId,
        _pledger: msg.sender,
        _token: _params.bondToken,
        _amount: _amountToRelease
      });
      emit PledgeClaimedDisputerWon(_requestId, _disputeId, msg.sender, _params.bondToken, _amountToRelease);
    } else if (_escalationData.resolution == Resolution.DisputerLost) {
      _pledgerBalanceBefore = pledgesAgainstDispute[_disputeId][msg.sender];
      pledgesAgainstDispute[_disputeId][msg.sender] -= _pledgerBalanceBefore;

      _pledgerProportion = FixedPointMathLib.mulDivDown(_pledgerBalanceBefore, BASE, _escalationData.pledgesAgainst);
      _reward = FixedPointMathLib.mulDivDown(_escalationData.pledgesFor, _pledgerProportion, BASE);
      _amountToRelease = _reward + _pledgerBalanceBefore;
      _params.accountingExtension.releasePledge({
        _requestId: _requestId,
        _disputeId: _disputeId,
        _pledger: msg.sender,
        _token: _params.bondToken,
        _amount: _amountToRelease
      });
      emit PledgeClaimedDisputerLost(_requestId, _disputeId, msg.sender, _params.bondToken, _amountToRelease);
    } else if (_escalationData.resolution == Resolution.NoResolution) {
      uint256 _pledgerBalanceFor = pledgesForDispute[_disputeId][msg.sender];
      uint256 _pledgerBalanceAgainst = pledgesAgainstDispute[_disputeId][msg.sender];

      if (_pledgerBalanceFor > 0) {
        pledgesForDispute[_disputeId][msg.sender] -= _pledgerBalanceFor;
        _params.accountingExtension.releasePledge({
          _requestId: _requestId,
          _disputeId: _disputeId,
          _pledger: msg.sender,
          _token: _params.bondToken,
          _amount: _pledgerBalanceFor
        });
        emit PledgeClaimedNoResolution(_requestId, _disputeId, msg.sender, _params.bondToken, _pledgerBalanceFor);
      }

      if (_pledgerBalanceAgainst > 0) {
        pledgesAgainstDispute[_disputeId][msg.sender] -= _pledgerBalanceAgainst;
        _params.accountingExtension.releasePledge({
          _requestId: _requestId,
          _disputeId: _disputeId,
          _pledger: msg.sender,
          _token: _params.bondToken,
          _amount: _pledgerBalanceAgainst
        });
        emit PledgeClaimedNoResolution(_requestId, _disputeId, msg.sender, _params.bondToken, _pledgerBalanceAgainst);
      }
    }
  }
}
