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
   * @param _target The target address for the callback
   * @param _requestId The id of the request being finalized
   * @param _data The calldata forwarded to the _target
   */
  event Callback(address indexed _target, bytes32 indexed _requestId, bytes _data);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the target address has no code (i.e. is not a contract)
   */
  error CallbackModule_TargetHasNoCode();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the decoded data for a request
   * @param _requestId The id of the request
   * @return _target The target address for the callback
   * @return _data The calldata forwarded to the _target
   */
  function decodeRequestData(bytes32 _requestId) external view returns (address _target, bytes memory _data);

  /**
   * @notice Finalizes the request by executing the callback call on the target
   * @dev The success of the callback call is purposely not checked
   * @param _requestId The id of the request
   */
  function finalizeRequest(bytes32 _requestId, address) external;
}
