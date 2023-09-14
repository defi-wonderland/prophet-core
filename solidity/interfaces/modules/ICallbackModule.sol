// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IFinalityModule} from './IFinalityModule.sol';

/**
 * @title CallbackModule
 * @notice Module allowing users to call a function on a contract
 * as a result of a request being finalized.
 */
interface ICallbackModule is IFinalityModule {
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
   * @notice Thrown when the target address has no code (i.e. is not a contract)
   */
  error CallbackModule_TargetHasNoCode();

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the request as stored in the module
   * @param target The target address for the callback
   * @param data The calldata forwarded to the _target
   */
  struct RequestParameters {
    address target;
    bytes data;
  }

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the decoded data for a request
   * @param _requestId The ID of the request
   * @return _params The struct containing the parameters for the request
   */
  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _params);

  /**
   * @notice Finalizes the request by executing the callback call on the target
   * @dev The success of the callback call is purposely not checked
   * @param _requestId The id of the request
   */
  function finalizeRequest(bytes32 _requestId, address) external;
}
