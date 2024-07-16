// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../interfaces/IOracle.sol';

/**
 * @title IDEncoder
 * @notice Library for encoding IDs of requests, responses and disputes
 */
library IDEncoder {
  bytes32 private constant _REQUEST_TYPEHASH = keccak256(
    'IOracle.Request(uint96 nonce,address requester,address requestModule,address responseModule,address disputeModule,address resolutionModule,address finalityModule,bytes requestModuleData,bytes responseModuleData,bytes disputeModuleData,bytes resolutionModuleData,bytes finalityModuleData)'
  );

  bytes32 private constant _RESPONSE_TYPEHASH =
    keccak256('IOracle.Response(address proposer,bytes32 requestId,bytes response)');

  bytes32 private constant _DISPUTE_TYPEHASH =
    keccak256('IOracle.Dispute(address disputer,address proposer,bytes32 responseId,bytes32 requestId)');

  /**
   * @notice Computes the ID of a given request
   *
   * @param _request The request to compute the ID for
   * @return _id The ID the request
   */
  function getId(IOracle.Request memory _request) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_REQUEST_TYPEHASH, _request));
  }

  /**
   * @notice Computes the ID of a given response
   *
   * @param _response The response to compute the ID for
   * @return _id The ID the response
   */
  function getId(IOracle.Response memory _response) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_RESPONSE_TYPEHASH, _response));
  }

  /**
   * @notice Computes the ID of a given dispute
   *
   * @param _dispute The dispute to compute the ID for
   * @return _id The ID the dispute
   */
  function getId(IOracle.Dispute memory _dispute) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_DISPUTE_TYPEHASH, _dispute));
  }
}
