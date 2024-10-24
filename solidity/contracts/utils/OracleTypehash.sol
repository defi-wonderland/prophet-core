// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

bytes32 constant _CREATE_TYPEHASH =
  keccak256('CreateRequest(Request _request,bytes32 _ipfsHash,AccessControl _accessControl');

bytes32 constant _PROPOSE_TYPEHASH = keccak256('ProposeResponse(Request _request,Response _response)');

bytes32 constant _DISPUTE_TYPEHASH = keccak256('DisputeResponse(Request _request,Response _response,Dispute _dispute)');

bytes32 constant _ESCALATE_TYPEHASH = keccak256('EscalateDispute(Request _request,Response _response,Dispute _dispute)');

bytes32 constant _RESOLVE_TYPEHASH = keccak256('ResolveDispute(Request _request,Response _response,Dispute _dispute)');

bytes32 constant _UPDATE_TYPEHASH =
  keccak256('UpdateDisputeStatus(Request _request,Response _response,Dispute _dispute,DisputeStatus _status)');

bytes32 constant _FINALIZE_TYPEHASH = keccak256('Finalize(Request _request,Response _response)');
