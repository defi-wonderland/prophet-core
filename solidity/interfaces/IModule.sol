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
   * @param _requestId The id of the request that was finalized
   * @param _response The final response
   * @param _finalizer The address that initiated the finalization
   */
  event RequestFinalized(bytes32 indexed _requestId, IOracle.Response _response, address _finalizer);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not the oracle
   */
  error Module_OnlyOracle();

  /**
   * @notice Thrown when the response provided does not match the request
   */
  error Module_InvalidResponseBody();

  /**
   * @notice Thrown when the dispute provided does not match the request or response
   */
  error Module_InvalidDisputeBody();

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the address of the oracle
   *
   * @return _oracle The address of the oracle
   */
  function ORACLE() external view returns (IOracle _oracle);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Finalizes the request
   *
   * @param _request The request being finalized
   * @param _response The final response
   * @param _finalizer The address that initiated the finalization
   */
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external;

  /**
   * @notice Validates parameters prior to creating a request
   *
   * @param _encodedParameters The encoded parameters for the request
   * @return _valid Boolean indicating if the parameters are valid or not
   */
  function validateParameters(bytes calldata _encodedParameters) external pure returns (bool _valid);

  /**
   * @notice Returns the name of the module.
   *
   * @return _moduleName The name of the module.
   */
  function moduleName() external view returns (string memory _moduleName);
}
