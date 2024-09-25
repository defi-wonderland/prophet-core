// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract OracleTypehash {
  bytes32 internal constant PROPOSE_TYPEHASH = keccak256('ProposeResponse(Request _request, Response _response)');
  bytes32 internal constant DISPUTE_TYPEHASH =
    keccak256('DisputeResponse(Request _request, Response _response, Dispute _dispute,)');
}
