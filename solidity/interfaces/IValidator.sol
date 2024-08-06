// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from './IOracle.sol';

/**
 * @title Validator
 * @notice Contract to validate requests, responses, and disputes
 */
interface IValidator {
  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the response provided does not exist
   */
  error Validator_InvalidResponse();

  /**
   * @notice Thrown when the dispute provided does not exist
   */
  error Validator_InvalidDispute();
  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The oracle contract
   */
  function ORACLE() external view returns (IOracle _oracle);
}
