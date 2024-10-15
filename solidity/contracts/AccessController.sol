// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAccessControlModule} from '../interfaces/modules/accessControl/IAccessControlModule.sol';

abstract contract AccessController {
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
    if (!_hasAccess) revert AccessController_NoAccess();
    _;
  }
}

// contract HorizonAccessControlModule {

//   function hasAccess(address _caller, address _user, bytes32, bytes, bytes) {
//       return horizonStaking.isAuthorized(_caller, _user);
//   }

// }
