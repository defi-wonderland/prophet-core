// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../../IModule.sol';

/**
 * @title ResponseModule
 * @notice Common interface for all response modules
 */
interface IAccessControlModule is IModule {
  /**
   * @notice Checks if the caller has access to the user
   * @param _caller The caller address
   * @param _user The user address
   * @param _typehash The typehash of the request
   * @param _params The parameters of the request
   * @param _data The data for access control validation
   * @return _hasAccess True if the caller has access to the user
   */
  function hasAccess(
    address _caller,
    address _user,
    bytes32 _typehash,
    bytes memory _params,
    bytes calldata _data
  ) external returns (bool _hasAccess);
}
