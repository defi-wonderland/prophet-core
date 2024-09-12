// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../../IModule.sol';

/**
 * @title ResponseModule
 * @notice Common interface for all response modules
 */
interface IAccessControlModule is IModule {
  function hasAccess(address _caller, address _user, bytes calldata _data) external view returns (bool _hasAccess);
}
