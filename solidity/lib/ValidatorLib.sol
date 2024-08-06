// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../interfaces/IOracle.sol';

library ValidatorLib {
  /**
   * @notice Thrown when the response provided does not match the request
   */
  error ValidatorLib_InvalidResponseBody();

  /**
   * @notice Thrown when the dispute provided does not match the request or response
   */
  error ValidatorLib_InvalidDisputeBody();

  /**
   * @notice Computes the id a given request
   *
   * @param _request The request to compute the id for
   * @return _id The id the request
   */
  function _getId(IOracle.Request calldata _request) public pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_request));
  }

  /**
   * @notice Computes the id a given response
   *
   * @param _response The response to compute the id for
   * @return _id The id the response
   */
  function _getId(IOracle.Response calldata _response) public pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_response));
  }

  /**
   * @notice Computes the id a given dispute
   *
   * @param _dispute The dispute to compute the id for
   * @return _id The id the dispute
   */
  function _getId(IOracle.Dispute calldata _dispute) public pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_dispute));
  }

  /**
   * @notice Validates the correctness and existance of a request-response pair
   *
   * @param _request The request to compute the id for
   * @param _response The response to compute the id for
   * @return _requestId The id the request
   * @return _responseId The id the response
   */
  function _validateRequestAndResponse(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response
  ) public pure returns (bytes32 _requestId, bytes32 _responseId) {
    _requestId = _getId(_request);
    _responseId = _getId(_response);

    if (_response.requestId != _requestId) revert ValidatorLib_InvalidResponseBody();
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
  ) public pure returns (bytes32 _responseId) {
    bytes32 _requestId = _getId(_request);
    _responseId = _getId(_response);

    if (_response.requestId != _requestId) revert ValidatorLib_InvalidResponseBody();
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
  ) public pure returns (bytes32 _disputeId) {
    bytes32 _requestId = _getId(_request);
    _disputeId = _getId(_dispute);

    if (_dispute.requestId != _requestId) revert ValidatorLib_InvalidDisputeBody();
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
  ) public pure returns (bytes32 _disputeId) {
    bytes32 _responseId = _getId(_response);
    _disputeId = _getId(_dispute);

    if (_dispute.responseId != _responseId) revert ValidatorLib_InvalidDisputeBody();
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
  ) public pure returns (bytes32 _responseId, bytes32 _disputeId) {
    bytes32 _requestId = _getId(_request);
    _responseId = _getId(_response);
    _disputeId = _getId(_dispute);

    if (_response.requestId != _requestId) revert ValidatorLib_InvalidResponseBody();
    if (_dispute.requestId != _requestId || _dispute.responseId != _responseId) {
      revert ValidatorLib_InvalidDisputeBody();
    }
  }
}
