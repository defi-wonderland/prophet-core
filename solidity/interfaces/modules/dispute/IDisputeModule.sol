// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../../IModule.sol';
import {IOracle} from '../../IOracle.sol';

interface IDisputeModule is IModule {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a response is disputed
   * @param _requestId The id of the request
   * @param _responseId The id of the response disputed
   * @param _disputeId The id of the dispute
   * @param _dispute The dispute that is being created
   */
  event ResponseDisputed(
    bytes32 indexed _requestId, bytes32 indexed _responseId, bytes32 indexed _disputeId, IOracle.Dispute _dispute
  );

  /**
   * @notice Emitted when a dispute status is updated
   * @param _disputeId The id of the dispute
   * @param _dispute The dispute
   * @param _status The new status of the dispute
   */
  event DisputeStatusChanged(bytes32 indexed _disputeId, IOracle.Dispute _dispute, IOracle.DisputeStatus _status);

  /*///////////////////////////////////////////////////////////////
                             FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Called by the oracle when a dispute has been made on a response
   * @dev Bonds the tokens of the disputer
   * @param _request The request
   * @param _response The disputed response
   * @param _dispute The dispute
   */
  function disputeResponse(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) external;

  /**
   * @notice Callback executed after a response to a dispute is received by the oracle
   * @param _disputeId The id of the dispute
   * @param _request The request
   * @param _response The disputed response
   * @param _dispute The dispute
   */
  function onDisputeStatusChange(
    bytes32 _disputeId,
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) external;
}
