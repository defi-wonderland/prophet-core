// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../IModule.sol';

/**
 * @title ResolutionModule
 * @notice Common interface for all resolution modules
 */
interface IResolutionModule is IModule {
  /**
   * @notice Starts the resolution process
   *
   * @param _disputeId The ID of the dispute
   */
  function startResolution(bytes32 _disputeId) external;

  /**
   * @notice Resolves a dispute
   *
   * @param _disputeId The ID of the dispute being resolved
   */
  function resolveDispute(bytes32 _disputeId) external;
}
