// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Access Controller Interface
 * @notice Interface for the access controller
 */
interface IAccessController {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice The access control struct
   * @param user The address of the user
   * @param data The data for access control validation
   */
  struct AccessControl {
    address user;
    bytes data;
  }

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Reverts if the caller has no access
   */
  error IAccessControlData_NoAccess();
}
