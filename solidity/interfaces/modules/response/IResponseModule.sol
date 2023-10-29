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
   *
   * @param _proposer The address of the proposer
   * @param _responseData The data to be stored as the response
   * @return _response The response object
   */
  function propose(
    IOracle.Request calldata _request,
    address _proposer,
    bytes calldata _responseData,
    address _sender
  ) external returns (IOracle.Response memory _response);

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
