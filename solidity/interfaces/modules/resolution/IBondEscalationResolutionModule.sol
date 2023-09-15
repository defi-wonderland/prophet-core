// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../IOracle.sol';
import {IResolutionModule} from './IResolutionModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IBondEscalationAccounting} from '../../extensions/IBondEscalationAccounting.sol';

interface IBondEscalationResolutionModule is IResolutionModule {
  enum InequalityStatus {
    Equalized,
    ForTurnToEqualize,
    AgainstTurnToEqualize
  }

  enum Resolution {
    Unresolved,
    DisputerWon,
    DisputerLost,
    NoResolution
  }

  /**
   * @notice Parameters of the request as stored in the module
   *
   * @param _accountingExtension   The accounting extension to use for this request.
   * @param _token                 The token to use for this request.
   * @param _percentageDiff        The percentage difference between the for and against pledges that triggers the change in voting turns.
   *                                This value should be between 1 and 100.
   * @param _pledgeThreshold       The amount of pledges that must be reached to achieve quorum and start triggering voting turns.
   * @param _timeUntilDeadline     The amount of time in seconds past the start time of the escalation until the resolution process is over.
   * @param _timeToBreakInequality The amount of time the pledgers in favor or against a dispute have to break the pledge inequality once the percentage
   *                                difference has been surpassed.
   */
  struct RequestParameters {
    IBondEscalationAccounting accountingExtension;
    IERC20 bondToken;
    uint256 percentageDiff;
    uint256 pledgeThreshold;
    uint256 timeUntilDeadline;
    uint256 timeToBreakInequality;
  }

  struct PledgerData {
    address pledger;
    uint256 pledges;
  }

  struct InequalityData {
    InequalityStatus inequalityStatus;
    uint256 time;
  }

  struct EscalationData {
    Resolution resolution;
    uint128 startTime;
    uint256 pledgesFor;
    uint256 pledgesAgainst;
  }

  event DisputeEscalated(bytes32 indexed _disputeId, bytes32 indexed requestId);
  event PledgedForDispute(
    address indexed _pledger, bytes32 indexed _requestId, bytes32 indexed _disputeId, uint256 _pledgedAmount
  );
  event PledgedAgainstDispute(
    address indexed _pledger, bytes32 indexed _requestId, bytes32 indexed _disputeId, uint256 _pledgedAmount
  );
  event PledgeClaimedDisputerWon(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address indexed _pledger,
    IERC20 _token,
    uint256 _pledgeReleased
  );
  event PledgeClaimedDisputerLost(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address indexed _pledger,
    IERC20 _token,
    uint256 _pledgeReleased
  );
  event PledgeClaimedNoResolution(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address indexed _pledger,
    IERC20 _token,
    uint256 _pledgeReleased
  );

  error BondEscalationResolutionModule_AlreadyResolved();
  error BondEscalationResolutionModule_NotResolved();
  error BondEscalationResolutionModule_NotEscalated();
  error BondEscalationResolutionModule_PledgingPhaseOver();
  error BondEscalationResolutionModule_PledgingPhaseNotOver();
  error BondEscalationResolutionModule_MustBeResolved();
  error BondEscalationResolutionModule_AgainstTurnToEqualize();
  error BondEscalationResolutionModule_ForTurnToEqualize();

  function BASE() external view returns (uint256 _base);
  function escalationData(bytes32 _disputeId)
    external
    view
    returns (Resolution _resolution, uint128 _startTime, uint256 _pledgesFor, uint256 _pledgesAgainst);
  function inequalityData(bytes32 _disputeId) external view returns (InequalityStatus _inequalityStatus, uint256 _time);
  function pledgesForDispute(bytes32 _disputeId, address _pledger) external view returns (uint256 _pledgesForDispute);
  function pledgesAgainstDispute(
    bytes32 _disputeId,
    address _pledger
  ) external view returns (uint256 _pledgesAgainstDispute);

  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _params);

  function pledgeForDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) external;
  function pledgeAgainstDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) external;
  function claimPledge(bytes32 _requestId, bytes32 _disputeId) external;
}
