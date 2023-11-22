// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '../interfaces/IModule.sol';
import {IOracle} from '../interfaces/IOracle.sol';

abstract contract Module is IModule {
  /// @inheritdoc IModule
  IOracle public immutable ORACLE;

  constructor(IOracle _oracle) payable {
    ORACLE = _oracle;
  }

  /**
   * @notice Checks that the caller is the oracle
   */
  modifier onlyOracle() {
    if (msg.sender != address(ORACLE)) revert Module_OnlyOracle();
    _;
  }

  /// @inheritdoc IModule
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external virtual onlyOracle {}

  /**
   * @notice Validates the correctness of a request-response pair
   *
   * @param _request The request to compute the id for
   * @param _response The response to compute the id for
   * @return _responseId The id the response
   */
  function _validateResponse(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response
  ) internal pure returns (bytes32 _responseId) {
    bytes32 _requestId = keccak256(abi.encode(_request));
    _responseId = keccak256(abi.encode(_response));
    if (_response.requestId != _requestId) revert Module_InvalidResponseBody();
  }

  /**
   * @notice Validates the correctness of a request-response-dispute triplet
   *
   * @param _request The request to compute the id for
   * @param _response The response to compute the id for
   * @param _dispute The dispute to compute the id for
   * @return _disputeId The id the dispute
   */
  function _validateDispute(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) internal pure returns (bytes32 _disputeId) {
    bytes32 _requestId = keccak256(abi.encode(_request));
    bytes32 _responseId = keccak256(abi.encode(_response));
    _disputeId = keccak256(abi.encode(_dispute));

    if (_dispute.requestId != _requestId || _dispute.responseId != _responseId) revert Module_InvalidDisputeBody();
    if (_response.requestId != _requestId) revert Module_InvalidResponseBody();
  }
}
