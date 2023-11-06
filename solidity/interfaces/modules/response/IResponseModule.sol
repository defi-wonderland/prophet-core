// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../../IModule.sol';
import {IOracle} from '../../IOracle.sol';

/**
 * @title ResponseModule
 * @notice Common interface for all response modules
 */
interface IResponseModule is IModule {
  // TODO: natspec
  /**
   * @notice Creates a new response for a given request
   */
  function propose(IOracle.Request calldata _request, IOracle.Response calldata _response, address _sender) external;
}
