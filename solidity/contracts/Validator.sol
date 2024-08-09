// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle, IValidator} from '../interfaces/IValidator.sol';

import {ValidatorLib} from '../libraries/ValidatorLib.sol';

abstract contract Validator is IValidator {
  /// @inheritdoc IValidator
  IOracle public immutable ORACLE;

  constructor(IOracle _oracle) {
    ORACLE = _oracle;
  }
  /**
   * @notice Computes the id a given request
   *
   * @param _request The request to compute the id for
   * @return _id The id the request
   */

  function _getId(IOracle.Request calldata _request) internal pure returns (bytes32 _id) {
    _id = ValidatorLib._getId(_request);
  }

  /**
   * @notice Computes the id a given response
   *
   * @param _response The response to compute the id for
   * @return _id The id the response
   */
  function _getId(IOracle.Response calldata _response) internal pure returns (bytes32 _id) {
    _id = ValidatorLib._getId(_response);
  }

  /**
   * @notice Computes the id a given dispute
   *
   * @param _dispute The dispute to compute the id for
   * @return _id The id the dispute
   */
  function _getId(IOracle.Dispute calldata _dispute) internal pure returns (bytes32 _id) {
    _id = ValidatorLib._getId(_dispute);
  }

  /**
   * @notice Validates the correctness and existance of a request-response pair
   *
   * @param _request The request to compute the id for
   * @param _response The response to compute the id for
   * @return _responseId The id the response
   */
  function _validateResponse(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response
  ) internal view returns (bytes32 _responseId) {
    _responseId = ValidatorLib._validateResponse(_request, _response);

    if (ORACLE.responseCreatedAt(_responseId) == 0) revert Validator_InvalidResponse();
  }

  /**
   * @notice Validates the correctness of a request-dispute pair
   *
   * @param _request The request to compute the id for
   * @param _dispute The dispute to compute the id for
   * @return _disputeId The id the dispute
   */
  function _validateDispute(
    IOracle.Request calldata _request,
    IOracle.Dispute calldata _dispute
  ) internal view returns (bytes32 _disputeId) {
    _disputeId = ValidatorLib._validateDispute(_request, _dispute);

    if (ORACLE.disputeCreatedAt(_disputeId) == 0) revert Validator_InvalidDispute();
  }

  /**
   * @notice Validates the correctness of a response-dispute pair
   *
   * @param _response The response to compute the id for
   * @param _dispute The dispute to compute the id for
   * @return _disputeId The id the dispute
   */
  function _validateDispute(
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) internal view returns (bytes32 _disputeId) {
    _disputeId = ValidatorLib._validateDispute(_response, _dispute);

    if (ORACLE.disputeCreatedAt(_disputeId) == 0) revert Validator_InvalidDispute();
  }

  /**
   * @notice Validates the correctness of a request-response-dispute triplet
   *
   * @param _request The request to compute the id for
   * @param _response The response to compute the id for
   * @param _dispute The dispute to compute the id for
   * @return _responseId The id the response
   * @return _disputeId The id the dispute
   */
  function _validateResponseAndDispute(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) internal view returns (bytes32 _responseId, bytes32 _disputeId) {
    (_responseId, _disputeId) = ValidatorLib._validateResponseAndDispute(_request, _response, _dispute);

    if (ORACLE.disputeCreatedAt(_disputeId) == 0) revert Validator_InvalidDispute();
  }
}
