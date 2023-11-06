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

  /**
   * @notice Called by the oracle when a dispute has been made on a response.
   * Bonds the tokens of the disputer.
   * @param _responseId The ID of the response being disputed
   * @param _disputer The address of the user who disputed the response
   * @return _dispute The dispute on the proposed response
   */
  function disputeResponse(
    IOracle.Request calldata _request,
    bytes32 _responseId,
    address _disputer,
    IOracle.Response calldata _response
  ) external returns (IOracle.Dispute memory _dispute);

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

  /**
   * @notice Called by the oracle when a dispute has been escalated.
   * @param _disputeId The ID of the dispute being escalated
   */
  function disputeEscalated(bytes32 _disputeId, IOracle.Dispute calldata _dispute) external;
}
