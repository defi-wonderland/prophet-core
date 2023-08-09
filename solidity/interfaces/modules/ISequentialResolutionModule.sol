// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../../interfaces/IOracle.sol';
import {IResolutionModule} from './IResolutionModule.sol';

interface ISequentialResolutionModule is IOracle {
  /// @notice Thrown when the caller is not a valid sub-module
  error SequentialResolutionModule_OnlySubmodule();

  /// @notice Thrown when the function called is not implemented
  error SequentialResolutionModule_NotImplemented();

  /// @notice Returns the list of submodules
  /// @param _startFrom The index to start from
  /// @param _batchSize The number of submodules to return
  /// @return _list The list of submodules
  function listSubmodules(
    uint256 _startFrom,
    uint256 _batchSize
  ) external view returns (IResolutionModule[] memory _list);
}
