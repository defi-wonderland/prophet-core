// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IBondEscalationResolutionModule} from '../../interfaces/modules/IBondEscalationResolutionModule.sol';
import {IOracle} from '../../interfaces/IOracle.sol';
import {IBondEscalationAccounting} from '../../interfaces/extensions/IBondEscalationAccounting.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {FixedPointMathLib} from 'solmate/utils/FixedPointMathLib.sol';

import {Module} from '../Module.sol';

contract BondEscalationResolutionModule is Module, IBondEscalationResolutionModule {
  using SafeERC20 for IERC20;

  uint256 public constant BASE = 1e18;

  mapping(bytes32 _disputeId => EscalationData _escalationData) public escalationData;
  mapping(bytes32 _disputeId => InequalityData _inequalityData) public inequalityData;

  mapping(bytes32 _disputeId => mapping(address _pledger => uint256 pledges)) public pledgesForDispute;
  mapping(bytes32 _disputeId => mapping(address _pledger => uint256 pledges)) public pledgesAgainstDispute;

  constructor(IOracle _oracle) Module(_oracle) {}

  /**
   * @notice Returns module name.
   *
   * @return _moduleName The name of the module.
   *
   */
  function moduleName() external pure returns (string memory _moduleName) {
    return 'BondEscalationResolutionModule';
  }

  function decodeRequestData(bytes32 _requestId) public view returns (RequestParameters memory _params) {
    _params = abi.decode(requestData[_requestId], (RequestParameters));
  }

  /**
   * @notice Starts the resolution process for a given dispute.
   *
   * @param _disputeId The ID of the dispute to start the resolution for.
   */
  function startResolution(bytes32 _disputeId) external onlyOracle {
    bytes32 _requestId = ORACLE.getDispute(_disputeId).requestId;
    escalationData[_disputeId].startTime = uint128(block.timestamp);
    emit ResolutionStarted(_requestId, _disputeId);
  }

  /**
   * @notice Allows users to pledge in favor of a given dispute. This means the user believes the proposed answer is
   *         incorrect and therefore wants the disputer to win his dispute.
   *
   * @param _requestId    The ID of the request associated with the dispute.
   * @param _disputeId    The ID of the dispute to pledge in favor of.
   * @param _pledgeAmount The amount of pledges to pledge.
   */
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

    _params.accountingExtension.pledge(msg.sender, _requestId, _disputeId, _params.bondToken, _pledgeAmount);
    emit PledgedForDispute(msg.sender, _requestId, _disputeId, _pledgeAmount);

    /*
      If the pledge threshold is not reached, we simply return as the threshold is the trigger that initiates the status-based pledging system.
      Once the threshold has been reached there are three possible statuses:
      1) Equalized:             The percentage difference between the for and against pledges is smaller than the set percentageDiff. This state allows any of the two
                                parties to pledge. When the percentageDiff is surpassed, the status changes to AgainstTurnToEqualize or ForTurnToEqualize depending on
                                which side surpassed the percentageDiff. When this happens, only the respective side can pledge.
      2) AgainstTurnToEqualize: If the for pledges surpassed the percentageDiff, a timer is started and the against party has a set amount of time to
                                reduce the percentageDiff so that the status is Equalized again, or to surpass the percentageDiff so that the status changes to ForTurnToEqualize. 
                                Until this happens, only the people pledging against a dispute can pledge.
                                If the timer runs out without the status changing, then the dispute is considered finalized and the for party wins.
      3) ForTurnToEqualize:     The same as AgainsTurnToEqualize but for the parties that wish to pledge in favor a given dispute.
    */
    if (_updatedTotalVotes >= _params.pledgeThreshold) {
      uint256 _updatedForVotes = _escalationData.pledgesFor;
      uint256 _againstVotes = _escalationData.pledgesAgainst;

      uint256 _newForVotesPercentage = FixedPointMathLib.mulDivDown(_updatedForVotes, BASE, _updatedTotalVotes);
      uint256 _againstVotesPercentage = FixedPointMathLib.mulDivDown(_againstVotes, BASE, _updatedTotalVotes);

      int256 _forPercentageDifference = int256(_newForVotesPercentage) - int256(_againstVotesPercentage);
      int256 _againstPercentageDifference = int256(_againstVotesPercentage) - int256(_newForVotesPercentage);

      int256 _scaledPercentageDiffAsInt = int256(_params.percentageDiff * BASE / 100);

      if (_againstPercentageDifference >= _scaledPercentageDiffAsInt) {
        return;
      } else if (_forPercentageDifference >= _scaledPercentageDiffAsInt) {
        _inequalityData.inequalityStatus = InequalityStatus.AgainstTurnToEqualize;
        _inequalityData.time = block.timestamp;
      } else if (_inequalityData.inequalityStatus == InequalityStatus.ForTurnToEqualize) {
        // At this point, both _forPercentageDiff and _againstPercentageDiff are < _percentageDiff
        _inequalityData.inequalityStatus = InequalityStatus.Equalized;
        _inequalityData.time = 0;
      }
    }
  }

  /**
   * @notice Allows users to pledge against a given dispute. This means the user believes the proposed answer is
   *         correct and therefore wants the disputer to lose his dispute.
   *
   * @param _requestId    The ID of the request associated with the dispute.
   * @param _disputeId    The ID of the dispute to pledge against of.
   * @param _pledgeAmount The amount of pledges to pledge.
   */
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

    _params.accountingExtension.pledge(msg.sender, _requestId, _disputeId, _params.bondToken, _pledgeAmount);
    emit PledgedAgainstDispute(msg.sender, _requestId, _disputeId, _pledgeAmount);

    /*
      If the pledge threshold is not reached, we simply return as the threshold is the trigger that initiates the status-based pledging system.
      Once the threshold has been reached there are three possible statuses:
      1) Equalized:             The percentage difference between the for and against pledges is smaller than the set percentageDiff. This state allows any of the two
                                parties to pledge. When the percentageDiff is surpassed, the status changes to AgainstTurnToEqualize or ForTurnToEqualize depending on
                                which side surpassed the percentageDiff. When this happens, only the respective side can pledge.
      2) AgainstTurnToEqualize: If the for pledges surpassed the percentageDiff, a timer is started and the against party has a set amount of time to
                                reduce the percentageDiff so that the status is Equalized again, or to surpass the percentageDiff so that the status changes to ForTurnToEqualize. 
                                Until this happens, only the people pledging against a dispute can pledge.
                                If the timer runs out without the status changing, then the dispute is considered finalized and the for party wins.
      3) ForTurnToEqualize:     The same as AgainsTurnToEqualize but for the parties that wish to pledge in favor a given dispute.
    */
    if (_updatedTotalVotes >= _params.pledgeThreshold) {
      uint256 _updatedAgainstVotes = _escalationData.pledgesAgainst;
      uint256 _forVotes = _escalationData.pledgesFor;

      uint256 _forVotesPercentage = FixedPointMathLib.mulDivDown(_forVotes, BASE, _updatedTotalVotes);
      uint256 _newAgainstVotesPercentage = FixedPointMathLib.mulDivDown(_updatedAgainstVotes, BASE, _updatedTotalVotes);
      int256 _forPercentageDifference = int256(_forVotesPercentage) - int256(_newAgainstVotesPercentage);
      int256 _againstPercentageDifference = int256(_newAgainstVotesPercentage) - int256(_forVotesPercentage);

      int256 _scaledPercentageDiffAsInt = int256(_params.percentageDiff * BASE / 100);

      if (_forPercentageDifference >= _scaledPercentageDiffAsInt) {
        return;
      } else if (_againstPercentageDifference >= _scaledPercentageDiffAsInt) {
        _inequalityData.inequalityStatus = InequalityStatus.ForTurnToEqualize;
        _inequalityData.time = block.timestamp;
      } else if (_inequalityData.inequalityStatus == InequalityStatus.AgainstTurnToEqualize) {
        // At this point, both _forPercentageDiff and _againstPercentageDiff are < _percentageDiff
        _inequalityData.inequalityStatus = InequalityStatus.Equalized;
        _inequalityData.time = 0;
      }
    }
  }

  /**
   * @notice Resolves a dispute.
   *
   * @dev Disputes can only be resolved if the deadline has expired, or if the part in charge of equalizing didn't do so in time.
   *
   * @param _disputeId The ID of the dispute to resolve.
   */
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

  /**
   * @notice Allows user to claim his corresponding pledges after a dispute is resolved.
   *
   * @dev Winning pledgers will claim their pledges along with their reward. In case of no resolution, users can
   *      claim their pledges back. Losing pledgers will go to the rewards of the winning pledgers.
   *
   * @param _requestId The ID of the request associated with dispute.
   * @param _disputeId The ID of the dispute the user wants to claim pledges from.
   */
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
      _params.accountingExtension.releasePledge(_requestId, _disputeId, msg.sender, _params.bondToken, _amountToRelease);
      emit PledgeClaimedDisputerWon(_requestId, _disputeId, msg.sender, _params.bondToken, _amountToRelease);
      return;
    }

    if (_escalationData.resolution == Resolution.DisputerLost) {
      _pledgerBalanceBefore = pledgesAgainstDispute[_disputeId][msg.sender];
      pledgesAgainstDispute[_disputeId][msg.sender] -= _pledgerBalanceBefore;

      _pledgerProportion = FixedPointMathLib.mulDivDown(_pledgerBalanceBefore, BASE, _escalationData.pledgesAgainst);
      _reward = FixedPointMathLib.mulDivDown(_escalationData.pledgesFor, _pledgerProportion, BASE);
      _amountToRelease = _reward + _pledgerBalanceBefore;
      _params.accountingExtension.releasePledge(_requestId, _disputeId, msg.sender, _params.bondToken, _amountToRelease);
      emit PledgeClaimedDisputerLost(_requestId, _disputeId, msg.sender, _params.bondToken, _amountToRelease);
      return;
    }

    // At this point the only possible resolution state is NoResolution
    uint256 _pledgerBalanceFor = pledgesForDispute[_disputeId][msg.sender];
    uint256 _pledgerBalanceAgainst = pledgesAgainstDispute[_disputeId][msg.sender];

    if (_pledgerBalanceFor > 0) {
      pledgesForDispute[_disputeId][msg.sender] -= _pledgerBalanceFor;
      _params.accountingExtension.releasePledge(
        _requestId, _disputeId, msg.sender, _params.bondToken, _pledgerBalanceFor
      );
      emit PledgeClaimedNoResolution(_requestId, _disputeId, msg.sender, _params.bondToken, _pledgerBalanceFor);
    }
    if (_pledgerBalanceAgainst > 0) {
      pledgesAgainstDispute[_disputeId][msg.sender] -= _pledgerBalanceAgainst;
      _params.accountingExtension.releasePledge(
        _requestId, _disputeId, msg.sender, _params.bondToken, _pledgerBalanceAgainst
      );
      emit PledgeClaimedNoResolution(_requestId, _disputeId, msg.sender, _params.bondToken, _pledgerBalanceAgainst);
    }
  }
}
