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
   * @param _requestId The id of the request being finalized
   * @param _target The target address for the callback
   * @param _data The calldata forwarded to the _target
   */
  event Callback(bytes32 indexed _requestId, address indexed _target, bytes _data);

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
                              STRUCTS 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the request as stored in the module
   * @param targets The target addresses for the callback
   * @param data The calldata forwarded to the targets
   */
  struct RequestParameters {
    address[] targets;
    bytes[] data;
  }
  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the decoded data for a request
   * @param _requestId The id of the request
   * @return _params The struct containing the parameters for the request
   */
  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _params);

  /**
   * @notice Finalizes the request by executing the callback calls on the targets
   * @dev The success of the callback calls is purposely not checked
   * @param _requestId The id of the request
   */
  function finalizeRequest(bytes32 _requestId, address) external;
}
