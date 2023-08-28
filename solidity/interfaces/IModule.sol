// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// TODO: Definition of base has to precede definition of derived contract
// import {IOracle} from './IOracle.sol';

/**
 * @title Module
 * @notice Abstract contract to be inherited by all modules
 */
interface IModule {
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
  // function ORACLE() external view returns (IOracle _oracle);

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
   * @param _requestId The ID of the request being finalized
   * @param _finalizer The address that initiated the finalization
   */
  function finalizeRequest(bytes32 _requestId, address _finalizer) external;

  /**
   * @notice Returns the name of the module.
   *
   * @return _moduleName The name of the module.
   */
  function moduleName() external view returns (string memory _moduleName);
}
