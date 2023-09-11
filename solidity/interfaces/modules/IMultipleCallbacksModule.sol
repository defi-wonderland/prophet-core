// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IFinalityModule} from './IFinalityModule.sol';

/**
 * @title MultipleCallbackModule
 * @notice Module allowing users to make multiple calls to different contracts
 * as a result of a request being finalized.
 */
interface IMultipleCallbacksModule is IFinalityModule {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice A callback has been executed
   * @param _target The target address for the callback
   * @param _requestId The id of the request being finalized
   * @param _data The calldata forwarded to the _target
   */
  event Callback(address indexed _target, bytes32 indexed _requestId, bytes _data);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when then target address has no code (i.e. is not a contract)
   */
  error MultipleCallbackModule_TargetHasNoCode();

  /**
   * @notice Thrown when the targets array and the data array have different lengths
   */
  error MultipleCallbackModule_InvalidParameters();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the decoded data for a request
   * @param _requestId The id of the request
   * @return _targets The target addresses for the callback
   * @return _data The calldata forwarded to the targets
   */
  function decodeRequestData(bytes32 _requestId)
    external
    view
    returns (address[] memory _targets, bytes[] memory _data);

  /**
   * @notice Finalizes the request by executing the callback calls on the targets
   * @dev The success of the callback calls is purposely not checked
   * @param _requestId The id of the request
   */
  function finalizeRequest(bytes32 _requestId, address) external;
}
