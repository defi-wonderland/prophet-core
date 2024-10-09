// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Module} from '../contracts/Module.sol';
import {IOracle} from '../interfaces/IOracle.sol';
import {IAccessControlModule} from '../interfaces/modules/accessControl/IAccessControlModule.sol';

abstract contract AccessController is Module {
  /**
   * @notice The access control struct
   * @param user The address of the user
   * @param data The data for access control validation
   */
  struct AccessControl {
    address user;
    bytes data;
  }

  error AccessController_NoAccess();

  constructor(
    IOracle _oracle
  ) Module(_oracle) {}

  /**
   * @notice Modifier to check if the caller has access to the user
   * @param _accessControlModule The access control module
   * @param _accessControl The access control struct
   */
  modifier hasAccess(
    address _accessControlModule,
    bytes32 _typehash,
    bytes memory _params,
    AccessControl memory _accessControl
  ) {
    bool _hasAccess = msg.sender == _accessControl.user
      || (
        _accessControlModule != address(0) && ORACLE.isAccessControlApproved(_accessControl.user, _accessControlModule)
          && IAccessControlModule(_accessControlModule).hasAccess({
            _caller: msg.sender,
            _user: _accessControl.user,
            _typehash: _typehash,
            _params: _params,
            _data: _accessControl.data
          })
      );
    if (!_hasAccess) revert AccessController_NoAccess();
    _;
  }
}
