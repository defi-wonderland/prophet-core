// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../../IModule.sol';

/**
 * @title ResponseModule
 * @notice Common interface for all response modules
 */
interface IAccessControlModule is IModule {
  function hasAccess(
    address _caller,
    address _user,
    bytes32 _typehash,
    bytes memory _params,
    bytes calldata _data
  ) external returns (bool _hasAccess);
}
