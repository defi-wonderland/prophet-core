// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IDisputeModule} from './IDisputeModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IOracle} from '../IOracle.sol';
import {IBondEscalationAccounting} from '../extensions/IBondEscalationAccounting.sol';

/**
 * @title BondEscalationModule
 * @notice Module allowing users to have the first dispute of a request go through the bond escalation mechanism.
 */
interface IBondEscalationModule is IDisputeModule {
  /**
   * @notice A pledge has been made in favor of a dispute.
   *
   * @param _disputeId The id of the dispute the pledger is pledging in favor of.
   * @param _pledger   The address of the pledger.
   * @param _amount    The amount pledged.
   */
  event PledgedInFavorOfDisputer(bytes32 indexed _disputeId, address indexed _pledger, uint256 indexed _amount);

  /**
   * @notice A pledge has been made against a dispute.
   *
   * @param _disputeId The id of the dispute the pledger is pledging against.
   * @param _pledger   The address of the pledger.
   * @param _amount    The amount pledged.
   */
  event PledgedInFavorOfProposer(bytes32 indexed _disputeId, address indexed _pledger, uint256 indexed _amount);

  /**
   * @notice The status of the bond escalation mechanism has been updated.
   *
   * @param _requestId The id of the request associated with the bond escalation mechanism.
   * @param _disputeId The id of the dispute going through the bond escalation mechanism.
   * @param _status    The new status.
   */
  event BondEscalationStatusUpdated(
    bytes32 indexed _requestId, bytes32 indexed _disputeId, BondEscalationStatus _status
  );

  /**
   * @notice Thrown when trying to escalate a dispute going through the bond escalation module before its deadline.
   */
  error BondEscalationModule_BondEscalationNotOver();
  /**
   * @notice Thrown when trying to pledge for a dispute that is not going through the bond escalation mechanism.
   */
  error BondEscalationModule_DisputeNotEscalated();
  /**
   * @notice Thrown when the number of escalation pledges of a given dispute has reached its maximum.
   */
  error BondEscalationModule_MaxNumberOfEscalationsReached();
  /**
   * @notice Thrown when trying to settle a dispute that went through the bond escalation when it's not active.
   */
  error BondEscalationModule_BondEscalationCantBeSettled();
  /**
   * @notice Thrown when trying to settle a bond escalation process that is not tied.
   */
  error BondEscalationModule_ShouldBeEscalated();
  /**
   * @notice Thrown when trying to tie outside of the tying buffer.
   */
  error BondEscalationModule_CanOnlyTieDuringTyingBuffer();
  /**
   * @notice Thrown when the max number of escalations or the bond size is set to 0.
   */
  error BondEscalationModule_ZeroValue();
  /**
   * @notice Thrown when trying to pledge after the bond escalation deadline.
   */
  error BondEscalationModule_BondEscalationOver();
  /**
   * @notice Thrown when trying to escalate a dispute going through the bond escalation process that is not tied
   *         or that is not active.
   */
  error BondEscalationModule_NotEscalatable();
  /**
   * @notice Thrown when trying to pledge for a dispute that does not exist
   */
  error BondEscalationModule_DisputeDoesNotExist();
  /**
   * @notice Thrown when trying to surpass the number of pledges of the other side by more than 1 in the bond escalation mechanism.
   */
  error BondEscalationModule_CanOnlySurpassByOnePledge();
  /**
   * @notice Thrown when trying to dispute a response after the challenge period expired.
   */
  error BondEscalationModule_ChallengePeriodOver();

  /**
   * @notice Enum holding all the possible statuses of a dispute going through the bond escalation mechanism.
   */
  enum BondEscalationStatus {
    None, // Dispute is not going through the bond escalation mechanism.
    Active, // Dispute is going through the bond escalation mechanism.
    Escalated, // Dispute is going through the bond escalation mechanism and has been escalated.
    DisputerLost, // An escalated dispute has been settled and the disputer lost.
    DisputerWon // An escalated dispute has been settled and the disputer won.
  }

  /**
   * @notice Struct containing an array of the pledgers in favor of a dispute and another containing those against it.
   */
  struct BondEscalationData {
    address[] pledgersForDispute; // Array of pledgers in favor of a given dispute.
    address[] pledgersAgainstDispute; // Array of pledges against a given dispute.
  }

  /**
   * @notice Struct containing the current bond escalation status of a given request through its id.
   */
  function bondEscalationStatus(bytes32 _requestId) external view returns (BondEscalationStatus _status);

  /**
   * @notice The dispute id of the dispute that is going through the bond escalation process for a given request.
   */
  function escalatedDispute(bytes32 _requestId) external view returns (bytes32 _disputeId);

  /**
   * @notice Disputes a response
   *
   * @dev If this is the first dispute of the request and the bond escalation window is not over,
   *      it will start the bond escalation process. This function must be called through the Oracle.
   *
   * @param _requestId  The ID of the request containing the response to dispute.
   * @param _responseId The ID of the request to dispute.
   * @param _disputer   The address of the disputer.
   * @param _proposer   The address of the proposer of the response.
   *
   * @return _dispute The data of the created dispute.
   */
  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external override returns (IOracle.Dispute memory _dispute);

  /**
   * @notice Updates the status of a given disputeId and pays the proposer and disputer accordingly. If this
   *         dispute has gone through the bond escalation mechanism, then it will pay the winning pledgers as well.
   *
   * @param _disputeId  The ID of the dispute to update the status for.
   * @param _dispute    The full dispute object.
   *
   */
  function updateDisputeStatus(bytes32 _disputeId, IOracle.Dispute memory _dispute) external override;

  /**
   * @notice Verifies whether the dispute going through the bond escalation mechanism has reached a tie and
   *         updates its escalation status accordingly.
   *
   * @param _disputeId The ID of the dispute to escalate.
   */
  function disputeEscalated(bytes32 _disputeId) external;

  /**
   * @notice Bonds funds in favor of a given dispute during the bond escalation process.
   *
   * @dev This function must be called directly through this contract.
   * @dev If the bond escalation is not tied at the end of its deadline, a tying buffer is added
   *      to avoid scenarios where one of the parties breaks the tie very last second.
   *      During the tying buffer, the losing party can only tie, and once the escalation is tied
   *      no further funds can be pledged.
   *
   * @param _disputeId  The ID of the dispute to pledge for.
   */
  function pledgeForDispute(bytes32 _disputeId) external;

  /**
   * @notice Pledges funds against a given disputeId during its bond escalation process.
   *
   * @dev Must be called directly through this contract. Will revert if the disputeId is not going through
   *         the bond escalation process.
   * @dev If the bond escalation is not tied at the end of its deadline, a tying buffer is added
   *      to avoid scenarios where one of the parties breaks the tie very last second.
   *      During the tying buffer, the losing party can only tie, and once the escalation is tied
   *      no further funds can be pledged.
   *
   * @param _disputeId ID of the dispute id to pledge against.
   */
  function pledgeAgainstDispute(bytes32 _disputeId) external;

  /**
   * @notice Settles the bond escalation process of a given requestId.
   *
   * @dev Must be called directly through this contract.
   * @dev Can only be called if after the deadline + tyingBuffer window is over, the pledges weren't tied
   *
   * @param _requestId requestId of the request to settle the bond escalation process for.
   */
  function settleBondEscalation(bytes32 _requestId) external;

  /**
   * @notice Decodes the request data associated to a request id.
   *
   * @param _requestId id of the request to decode.
   *
   * @return _accountingExtension         Address of the accounting extension associated with the given request
   * @return _bondToken                   Address of the token associated with the given request
   * @return _bondSize                    Amount to bond to dispute or propose an answer for the given request
   * @return _numberOfEscalations         Maximum allowed escalations or pledges for each side during the bond
   *                                      escalation process
   * @return _bondEscalationDeadline      Timestamp at which bond escalation process finishes when pledges are not tied
   * @return _tyingBuffer                 Number of seconds to extend the bond escalation process to allow the losing
   *                                      party to tie if at the end of the initial deadline the pledges weren't tied.
   * @return _challengePeriod             Number of seconds disputers have to challenge the proposed response since its creation.
   */

  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (
      IBondEscalationAccounting _accountingExtension,
      IERC20 _bondToken,
      uint256 _bondSize,
      uint256 _numberOfEscalations,
      uint256 _bondEscalationDeadline,
      uint256 _tyingBuffer,
      uint256 _challengePeriod
    );

  /**
   * @notice Fetches the addresses that pledged in favor of a dispute during the bond escalation process
   *
   * @dev This will return an empty array if the dispute never went through the bond escalation process.
   *
   * @param _disputeId id of the dispute to retrieve the for-pledgers from.
   *
   * @return _pledgersForDispute Addresses that pledged in favor of the dispute during the bond escalation process
   */
  function fetchPledgersForDispute(bytes32 _disputeId) external view returns (address[] memory _pledgersForDispute);

  /**
   * @notice Fetches the addresses that pledged against a dispute during the bond escalation process
   *
   * @dev This will return an empty array if the dispute never went through the bond escalation process.
   *
   * @param _disputeId id of the dispute to retrieve the addresses of the pledgers against it from.
   *
   * @return _pledgersAgainstDispute Addresses that pledged against the given dispute during the bond escalation process
   */
  function fetchPledgersAgainstDispute(bytes32 _disputeId)
    external
    view
    returns (address[] memory _pledgersAgainstDispute);
}
