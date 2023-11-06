// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../../IModule.sol';
import {IOracle} from '../../IOracle.sol';

/**
 * @title ResolutionModule
 * @notice Common interface for all resolution modules
 */
interface IResolutionModule is IModule {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Emitted when a dispute has been resolved
   * @param _requestId The id for the request that was disputed
   * @param _disputeId The id for the dispute that was resolved
   * @param _status The final result of the resolution
   */
  event DisputeResolved(bytes32 indexed _requestId, bytes32 indexed _disputeId, IOracle.DisputeStatus _status);

  /**
   * @notice Emitted when a resolution is started
   * @param _requestId The id for the request for the dispute
   * @param _disputeId The id for the dispute that the resolution was started for
   */
  event ResolutionStarted(bytes32 indexed _requestId, bytes32 indexed _disputeId);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Starts the resolution process
   *
   * @param _disputeId The id of the dispute
   */
  function startResolution(bytes32 _disputeId, IOracle.Dispute calldata _dispute) external;

  /**
   * @notice Resolves a dispute
   *
   * @param _disputeId The id of the dispute being resolved
   */
  function resolveDispute(bytes32 _disputeId, IOracle.Dispute calldata _dispute) external;
}
