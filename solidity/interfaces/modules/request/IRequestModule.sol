// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../../IModule.sol';

interface IRequestModule is IModule {
  /**
   * @notice Called by the oracle when a request has been made
   * @param _requestId The id of the request
   * @param _data The data of the request
   * @param _requester The address of the requester
   */
  function createRequest(bytes32 _requestId, bytes calldata _data, address _requester) external;
}
