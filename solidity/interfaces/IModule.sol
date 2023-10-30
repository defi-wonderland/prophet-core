// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../interfaces/IOracle.sol';

/**
 * @title Module
 * @notice Abstract contract to be inherited by all modules
 */
interface IModule {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a request is finalized
   * @param _requestId The ID of the request that was finalized
   * @param _finalizer The address that initiated the finalization
   */
  event RequestFinalized(bytes32 indexed _requestId, address _finalizer);
  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not the oracle
   */
  error Module_OnlyOracle();

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the address of the oracle
   *
   * @return _oracle The address of the oracle
   */
  function oracle() external view returns (address _oracle);

  /**
   * @notice Returns the data of the request associated with the provided id
   *
   * @param _requestId The id of the request
   * @return _requestData The data of the request
   */
  function requestData(bytes32 _requestId) external view returns (bytes memory _requestData);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Stores the request data and runs module-specific hooks
   *
   * @param _requestId The ID of the request
   * @param _data The data of the request
   */
  function setupRequest(bytes32 _requestId, bytes calldata _data) external;

  /**
   * @notice Finalizes a given request and executes any additional logic set by the chosen modules
   *
   * @param _finalizer The address that initiated the finalization
   */
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external;

  /**
   * @notice Returns the name of the module.
   *
   * @return _moduleName The name of the module.
   */
  function moduleName() external view returns (string memory _moduleName);
}
