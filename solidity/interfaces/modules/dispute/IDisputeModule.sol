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
   * @param _requestId The id of the request created
   * @param _responseId The id of the response disputed
   * @param _disputer The address of the disputed
   * @param _proposer The address of the proposer
   */
  event ResponseDisputed(bytes32 indexed _requestId, bytes32 _responseId, address _disputer, address _proposer);

  /**
   * @notice Emitted when a dispute status is updated
   * @param _requestId The id of the request
   * @param _responseId The id of the response
   * @param _disputer The address of the disputed
   * @param _proposer The address of the proposer
   * @param _status The new status of the dispute
   */
  event DisputeStatusChanged(
    bytes32 indexed _requestId, bytes32 _responseId, address _disputer, address _proposer, IOracle.DisputeStatus _status
  );
  /*///////////////////////////////////////////////////////////////
                             FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    address _disputer,
    address _proposer
  ) external returns (IOracle.Dispute memory _dispute);

  /**
   * @notice Callback executed after a response to a dispute is received by the oracle
   * @param _disputeId The id of the dispute
   * @param _dispute The dispute data
   */
  function onDisputeStatusChange(bytes32 _disputeId, IOracle.Dispute memory _dispute) external;

  function disputeEscalated(bytes32 _disputeId) external;
}
