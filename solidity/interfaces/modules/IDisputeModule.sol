// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../IModule.sol';
import {IOracle} from '../IOracle.sol';

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
   * @param _disputerWon True if the disputer won the dispute
   */
  event DisputeStatusUpdated(
    bytes32 indexed _requestId, bytes32 _responseId, address _disputer, address _proposer, bool _disputerWon
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

  function updateDisputeStatus(bytes32 _disputeId, IOracle.Dispute memory _dispute) external;
  function disputeEscalated(bytes32 _disputeId) external;
}
