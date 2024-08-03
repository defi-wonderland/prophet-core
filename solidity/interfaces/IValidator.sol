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
   * @notice Thrown when the response provided does not match the request
   */
  error Validator_InvalidResponseBody();

  /**
   * @notice Thrown when the dispute provided does not match the request or response
   */
  error Validator_InvalidDisputeBody();

  /**
   * @notice Thrown when the response provided does not exist
   */
  error Validator_InvalidResponse();

  /**
   * @notice Thrown when the dispute provided does not exist
   */
  error Validator_InvalidDispute();
}
