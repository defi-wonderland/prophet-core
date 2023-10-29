// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../../IModule.sol';
import {IOracle} from '../../IOracle.sol';

/**
 * @title ResponseModule
 * @notice Common interface for all response modules
 */
interface IResponseModule is IModule {
  /**
   * @notice Creates a new response for a given request
   */
  function propose(
    bytes32 _requestId,
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _sender
  ) external;

  /**
   * @notice Deletes a response
   *
   * @dev In most cases, deleting a disputed response should not be allowed
   * @param _requestId The ID of the request to delete the response from
   * @param _responseId The ID of the response to delete
   * @param _proposer The address of the proposer
   */
  function deleteResponse(bytes32 _requestId, bytes32 _responseId, address _proposer) external;
}
