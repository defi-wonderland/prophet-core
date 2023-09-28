// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../IOracle.sol';
import {IResolutionModule} from './IResolutionModule.sol';

interface ISequentialResolutionModule is IOracle, IResolutionModule {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a new resolution sequence is added
   */
  event ResolutionSequenceAdded(uint256 _sequenceId, IResolutionModule[] _modules);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Thrown when the caller is not a valid sub-module
   */
  error SequentialResolutionModule_OnlySubmodule();

  /**
   * @notice Thrown when the function called is not implemented
   */
  error SequentialResolutionModule_NotImplemented();

  /**
   * @notice Thrown when trying to add a new sequenceId that was already used
   * @param _sequenceId The sequenceId that was already used
   */
  error SequentialResolutionModule_SequenceIdAlreadyUsed(uint256 _sequenceId);

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Parameters of the request as stored in the module
   * @param sequenceId The sequence ID to use in the request.
   * @param submoduleData The array of data to pass to the submodules
   */
  struct RequestParameters {
    uint256 sequenceId;
    bytes[] submoduleData;
  }

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the last sequence id that was created
   * @return _currentSequenceId The sequence id
   */
  function currentSequenceId() external view returns (uint256 _currentSequenceId);

  /**
   * @notice Returns the current index of the submodule in use for a dispute
   * @param _disputeId The disputeId
   * @return _moduleIndex The index of the module
   */
  function currentModuleIndex(bytes32 _disputeId) external view returns (uint256 _moduleIndex);

  /**
   * @notice Returns the requestId corresponding to a dispute
   * @param _disputeId The disputeId
   * @return _requestId The requestId
   */
  function requestIdForDispute(bytes32 _disputeId) external view returns (bytes32 _requestId);

  /**
   * @notice Returns the decoded data for a request
   * @param _requestId The ID of the request
   * @return _params The struct containing the parameters for the request
   */
  function decodeRequestData(bytes32 _requestId) external view returns (RequestParameters memory _params);

  /*///////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Returns the list of submodules
   * @param _startFrom The index to start from
   * @param _batchSize The number of submodules to return
   * @param _sequenceId The sequence to get the submodules from
   * @return _list The list of submodules
   */
  function listSubmodules(
    uint256 _startFrom,
    uint256 _batchSize,
    uint256 _sequenceId
  ) external view returns (IResolutionModule[] memory _list);

  /**
   * @notice Adds a sequence of modules to the resolution module registry.
   * @param _modules The modules to add to the sequence.
   * @return _sequenceId The sequenceId created
   */
  function addResolutionModuleSequence(IResolutionModule[] memory _modules) external returns (uint256 _sequenceId);

  /**
   * @notice Returns the module that is currently resolving the specified dispute
   * @param _disputeId The id of the dispute
   * @return _module Te current resolution module
   */
  function getCurrentResolutionModule(bytes32 _disputeId) external returns (IResolutionModule _module);

  /**
   * @notice Resolves a dispute
   * @param _disputeId The id of the dispute to resolve
   */
  function resolveDispute(bytes32 _disputeId) external override(IOracle, IResolutionModule);
}
