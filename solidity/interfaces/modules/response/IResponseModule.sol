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
   * @param _request The request to create a response for
   * @param _response The response to create
   * @param _sender The creator of the response
   */
  function propose(IOracle.Request calldata _request, IOracle.Response calldata _response, address _sender) external;

  /**
   * @notice Refunds the proposer for a valid and unutilized response
   *
   * @param _request The request
   * @param _response The unutilized response
   */
  function releaseUnutilizedResponse(IOracle.Request calldata _request, IOracle.Response calldata _response) external;
}
