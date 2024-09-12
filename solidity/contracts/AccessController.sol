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

  /**
   * @notice Modifier to check if the caller has access to the user
   * @param _caller The caller of the function
   * @param _user The user to check access for
   * @param _data The data to check access for
   */
  modifier hasAccess(IAccessControlModule _accessControlModule, address _caller, AccessControl memory _accessControl) {
    if (
      _caller == _accessControl.user
        || (
          address(_accessControlModule) != address(0)
            && _accessControlModule.hasAccess(_caller, _accessControl.user, _accessControl.data)
        )
    ) revert AccessController_NoAccess();
    _;
  }
}
