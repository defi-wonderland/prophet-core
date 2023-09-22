// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from './IOracle.sol';

interface IArbitrator {
  /**
   * @notice Returns the status of a dispute
   * @param _dispute The ID of the dispute
   * @return _status The status of the dispute
   */
  function getAnswer(bytes32 _dispute) external returns (IOracle.DisputeStatus _status);

  /**
   * @notice Resolves a dispute
   * @param _disputeId The ID of the dispute
   * @return _data The data for the dispute resolution
   */
  function resolve(bytes32 _disputeId) external returns (bytes memory _data);
}
