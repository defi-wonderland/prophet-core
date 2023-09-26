// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IResolutionModule} from './IResolutionModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IBondEscalationAccounting} from '../../extensions/IBondEscalationAccounting.sol';

/**
 * @title BondEscalationResolutionModule
 * @notice Handles the bond escalation resolution process for disputes, in which sides take turns pledging for or against a dispute by bonding tokens.
 * @dev This is a resolution module, similar in its mechanics to the BondEscalationModule.
 */
interface IBondEscalationResolutionModule is IResolutionModule {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a dispute is escalated.
   *
   * @param _disputeId The ID of the dispute that was escalated.
   * @param _requestId The ID of the request associated with the dispute.
   */
  event DisputeEscalated(bytes32 indexed _disputeId, bytes32 indexed _requestId);

  /**
   * @notice Emitted when a user pledges in favor of a dispute.
   *
   * @param _pledger       The address of the user that pledged.
   * @param _requestId     The ID of the request associated with the dispute.
   * @param _disputeId     The ID of the dispute the user pledged in favor of.
   * @param _pledgedAmount The amount of tokens the user pledged.
   */
  event PledgedForDispute(
    address indexed _pledger, bytes32 indexed _requestId, bytes32 indexed _disputeId, uint256 _pledgedAmount
  );

  /**
   * @notice Emitted when a user pledges against a dispute.
   *
   * @param _pledger       The address of the user that pledged.
   * @param _requestId     The ID of the request associated with the dispute.
   * @param _disputeId     The ID of the dispute the user pledged against.
   * @param _pledgedAmount The amount of tokens the user pledged.
   */
  event PledgedAgainstDispute(
    address indexed _pledger, bytes32 indexed _requestId, bytes32 indexed _disputeId, uint256 _pledgedAmount
  );

  /**
   * @notice Emitted when a user claims his pledges after a successful dispute.
   *
   * @param _requestId      The ID of the request associated with the dispute.
   * @param _disputeId      The ID of the dispute the user supported.
   * @param _pledger        The address of the user that claimed his pledges.
   * @param _token          The token the user claimed his pledges in.
   * @param _pledgeReleased The amount of tokens the user claimed.
   */
  event PledgeClaimedDisputerWon(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address indexed _pledger,
    IERC20 _token,
    uint256 _pledgeReleased
  );

  /**
   * @notice Emitted when a user claims his pledges after a lost dispute.
   *
   * @param _requestId      The ID of the request associated with the dispute.
   * @param _disputeId      The ID of the dispute the user opposed.
   * @param _pledger        The address of the user that claimed his pledges.
   * @param _token          The token the user claimed his pledges in.
   * @param _pledgeReleased The amount of tokens the user claimed.
   */
  event PledgeClaimedDisputerLost(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address indexed _pledger,
    IERC20 _token,
    uint256 _pledgeReleased
  );

  /**
   * @notice Emitted when a user claims his pledges after a dispute with no resolution.
   *
   * @param _requestId      The ID of the request associated with the dispute.
   * @param _disputeId      The ID of the dispute the user supported or opposed.
   * @param _pledger        The address of the user that claimed his pledges.
   * @param _token          The token the user claimed his pledges in.
   * @param _pledgeReleased The amount of tokens the user claimed.
   */
  event PledgeClaimedNoResolution(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address indexed _pledger,
    IERC20 _token,
    uint256 _pledgeReleased
  );

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the user tries to resolve a dispute that has already been resolved.
   */
  error BondEscalationResolutionModule_AlreadyResolved();

  /**
   * @notice Thrown when trying to claim a pledge for a dispute that has not been resolved yet.
   */
  error BondEscalationResolutionModule_NotResolved();

  /**
   * @notice Thrown when the user tries to pledge for or resolve a non-existent dispute.
   */
  error BondEscalationResolutionModule_NotEscalated();

  /**
   * @notice Thrown when trying to pledge after the pledging phase is over.
   */
  error BondEscalationResolutionModule_PledgingPhaseOver();

  /**
   * @notice Thrown when trying to resolve a dispute before the pledging phase is over.
   */
  error BondEscalationResolutionModule_PledgingPhaseNotOver();

  /**
   * @notice Thrown when trying to pledge after the inequality timer has passed.
   */
  error BondEscalationResolutionModule_MustBeResolved();

  /**
   * @notice Thrown when trying to pledge for a dispute during the opposing side's pledging turn.
   */
  error BondEscalationResolutionModule_AgainstTurnToEqualize();

  /**
   * @notice Thrown when trying to pledge against a dispute during the supporting side's pledging turn.
   */
  error BondEscalationResolutionModule_ForTurnToEqualize();

  /*///////////////////////////////////////////////////////////////
                              ENUMS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The possible inequality statuses of a dispute
   *
   * @param Equalized             The percentage difference between the for and against pledges is smaller than the set percentageDiff. This state allows any of the two
   *                                   parties to pledge. When the percentageDiff is surpassed, the status changes to AgainstTurnToEqualize or ForTurnToEqualize depending on
   *                                   which side surpassed the percentageDiff. When this happens, only the respective side can pledge.
   * @param ForTurnToEqualize      If the for pledges surpassed the percentageDiff, a timer is started and the against party has a set amount of time to
   *                                   reduce the percentageDiff so that the status is Equalized again, or to surpass the percentageDiff so that the status changes to ForTurnToEqualize.
   *                                   Until this happens, only the people pledging against a dispute can pledge.
   *                                   If the timer runs out without the status changing, then the dispute is considered finalized and the for party wins.
   * @param AgainstTurnToEqualize  The same as AgainstTurnToEqualize but for the parties that wish to pledge in favor a given dispute.
   */
  enum InequalityStatus {
    Equalized,
    ForTurnToEqualize,
    AgainstTurnToEqualize
  }

  /**
   * @notice The possible resolutions of a dispute
   *
   * @param Unresolved    The dispute has not been resolved yet.
   * @param DisputerWon   The disputer won the dispute.
   * @param DisputerLost  The disputer lost the dispute.
   * @param NoResolution  The dispute was not resolved.
   */
  enum Resolution {
    Unresolved,
    DisputerWon,
    DisputerLost,
    NoResolution
  }

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the request as stored in the module
   *
   * @param _accountingExtension   The accounting extension to use for this request.
   * @param _token                 The token to use for this request.
   * @param _percentageDiff        The percentage difference between the for and against pledges that triggers the change in voting turns. This value should be between 1 and 100.
   * @param _pledgeThreshold       The amount of pledges that must be reached to achieve quorum and start triggering voting turns.
   * @param _timeUntilDeadline     The amount of time in seconds past the start time of the escalation until the resolution process is over.
   * @param _timeToBreakInequality The amount of time the pledgers have to break the pledge inequality once the percentage difference has been surpassed.
   */
  struct RequestParameters {
    IBondEscalationAccounting accountingExtension;
    IERC20 bondToken;
    uint256 percentageDiff;
    uint256 pledgeThreshold;
    uint256 timeUntilDeadline;
    uint256 timeToBreakInequality;
  }

  /**
   * @notice The inequality status and its last update time of a given dispute.
   *
   * @param _inequalityStatus The current status of the inequality.
   * @param _time             The time at which the inequality was last updated.
   */
  struct InequalityData {
    InequalityStatus inequalityStatus;
    uint256 time;
  }

  /**
   * @notice The bond escalation progress and the balance of pledges for and against a given dispute.
   *
   * @param _resolution     The current resolution of the dispute.
   * @param _startTime      The time at which the dispute was escalated.
   * @param _pledgesFor     The amount of pledges in favor of the dispute.
   * @param _pledgesAgainst The amount of pledges against the dispute.
   */
  struct Escalation {
    Resolution resolution;
    uint128 startTime;
    uint256 pledgesFor;
    uint256 pledgesAgainst;
  }

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Base to avoid over/underflow
   *
   * @return _base The base to avoid over/underflow
   */
  function BASE() external view returns (uint256 _base);

  /**
   * @notice Returns the bond escalation progress and the balance of pledges for and against a given dispute.
   *
   * @param _disputeId The ID of the dispute.
   *
   * @return _resolution The current resolution of the dispute.
   * @return _startTime  The time at which the dispute was escalated.
   * @return _pledgesFor The amount of pledges in favor of the dispute.
   * @return _pledgesAgainst The amount of pledges against the dispute.
   */
  function escalations(bytes32 _disputeId)
    external
    view
    returns (Resolution _resolution, uint128 _startTime, uint256 _pledgesFor, uint256 _pledgesAgainst);

  /**
   * @notice Returns the inequality status and its last update time of a given dispute.
   *
   * @param _disputeId The ID of the dispute.
   *
   * @return _inequalityStatus The current status of the inequality.
   * @return _time             The time at which the inequality was last updated.
   */
  function inequalityData(bytes32 _disputeId) external view returns (InequalityStatus _inequalityStatus, uint256 _time);

  /**
   * @notice Returns the amount pledged by a user for a given dispute.
   *
   * @param _disputeId The ID of the dispute.
   * @param _pledger   The address of the user.
   *
   * @return _pledgesForDispute The amount pledged by a user for a given dispute.
   */
  function pledgesForDispute(bytes32 _disputeId, address _pledger) external view returns (uint256 _pledgesForDispute);

  /**
   * @notice Returns the amount pledged by a user against a given dispute.
   *
   * @param _disputeId The ID of the dispute.
   * @param _pledger   The address of the user.
   *
   * @return _pledgesAgainstDispute The amount pledged by a user against a given dispute.
   */
  function pledgesAgainstDispute(
    bytes32 _disputeId,
    address _pledger
  ) external view returns (uint256 _pledgesAgainstDispute);

  /**
   * @notice Returns the decoded data for a request
   * @param _requestId The ID of the request
   * @return _params The struct containing the parameters for the request
   */
  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _params);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Allows users to pledge in favor of a given dispute. This means the user believes the proposed answer is
   *         incorrect and therefore wants the disputer to win his dispute.
   *
   * @param _requestId    The ID of the request associated with the dispute.
   * @param _disputeId    The ID of the dispute to pledge in favor of.
   * @param _pledgeAmount The amount of pledges to pledge.
   */
  function pledgeForDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) external;

  /**
   * @notice Allows users to pledge against a given dispute. This means the user believes the proposed answer is
   *         correct and therefore wants the disputer to lose his dispute.
   *
   * @param _requestId    The ID of the request associated with the dispute.
   * @param _disputeId    The ID of the dispute to pledge against of.
   * @param _pledgeAmount The amount of pledges to pledge.
   */
  function pledgeAgainstDispute(bytes32 _requestId, bytes32 _disputeId, uint256 _pledgeAmount) external;

  /**
   * @notice Allows user to claim his corresponding pledges after a dispute is resolved.
   *
   * @dev Winning pledgers will claim their pledges along with their reward. In case of no resolution, users can
   *      claim their pledges back. Losing pledgers will go to the rewards of the winning pledgers.
   *
   * @param _requestId The ID of the request associated with dispute.
   * @param _disputeId The ID of the dispute the user wants to claim pledges from.
   */
  function claimPledge(bytes32 _requestId, bytes32 _disputeId) external;
}
