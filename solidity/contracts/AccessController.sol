// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAccessController} from '../interfaces/IAccessController.sol';
import {IAccessControlModule} from '../interfaces/modules/accessControl/IAccessControlModule.sol';

abstract contract AccessController is IAccessController {
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
        _accessControlModule != address(0)
          && IAccessControlModule(_accessControlModule).hasAccess({
            _caller: msg.sender,
            _user: _accessControl.user,
            _typehash: _typehash,
            _params: _params,
            _data: _accessControl.data
          })
      );
    if (!_hasAccess) revert AccessControlData_NoAccess();
    _;
  }
}
