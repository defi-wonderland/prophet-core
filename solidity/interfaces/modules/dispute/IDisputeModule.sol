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
   * @param _responseId The id of the response disputed
   * @param _disputeId The id of the dispute
   * @param _dispute The dispute that is being created
   * @param _blockNumber The current block number
   */
  event ResponseDisputed(
    bytes32 indexed _requestId,
    bytes32 indexed _responseId,
    bytes32 indexed _disputeId,
    IOracle.Dispute _dispute,
    uint256 _blockNumber
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
   * @notice Called by the oracle when a dispute has been made on a response.
   * Bonds the tokens of the disputer.
   * @param _request The id of the response being disputed
   * @param _response The id of the response being disputed
   * @param _dispute The id of the response being disputed
   */
  function disputeResponse(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) external;

  /**
   * @notice Callback executed after a response to a dispute is received by the oracle
   * @param _disputeId The id of the dispute
   * @param _dispute The dispute data
   */
  function onDisputeStatusChange(
    bytes32 _disputeId,
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) external;
}
