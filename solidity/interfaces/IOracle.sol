// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRequestModule} from './modules/IRequestModule.sol';
import {IResponseModule} from './modules/IResponseModule.sol';
import {IDisputeModule} from './modules/IDisputeModule.sol';
import {IResolutionModule} from './modules/IResolutionModule.sol';
import {IFinalityModule} from './modules/IFinalityModule.sol';

interface IOracle {
  /// @notice Thrown when the caller of the slash() function is not the DisputeModule
  error Oracle_NotResolutionModule(address _caller);
  error Oracle_NotDisputeModule(address _caller);

  error Oracle_ResponseAlreadyDisputed(bytes32 _responseId);
  error Oracle_AlreadyFinalized(bytes32 _requestId);
  error Oracle_InvalidFinalizedResponse(bytes32 _responseId);
  error Oracle_InvalidDisputeId(bytes32 _disputeId);
  error Oracle_CannotEscalate(bytes32 _disputeId);
  error Oracle_CannotResolve(bytes32 _disputeId);
  error Oracle_NoResolutionModule(bytes32 _disputeId);

  // stored request
  struct Request {
    bytes32 ipfsHash;
    IRequestModule requestModule;
    IResponseModule responseModule;
    IDisputeModule disputeModule;
    IResolutionModule resolutionModule;
    IFinalityModule finalityModule;
    address requester;
    uint256 nonce;
    uint256 createdAt;
  }

  // Request as sent by users
  struct NewRequest {
    bytes requestModuleData;
    bytes responseModuleData;
    bytes disputeModuleData;
    bytes resolutionModuleData;
    bytes finalityModuleData;
    bytes32 ipfsHash;
    IRequestModule requestModule;
    IResponseModule responseModule;
    IDisputeModule disputeModule;
    IResolutionModule resolutionModule;
    IFinalityModule finalityModule;
  }

  // For offchain/getters
  struct FullRequest {
    bytes requestModuleData;
    bytes responseModuleData;
    bytes disputeModuleData;
    bytes resolutionModuleData;
    bytes finalityModuleData;
    bytes32 ipfsHash;
    IRequestModule requestModule;
    IResponseModule responseModule;
    IDisputeModule disputeModule;
    IResolutionModule resolutionModule;
    IFinalityModule finalityModule;
    address requester;
    uint256 nonce;
    uint256 createdAt;
    bytes32 requestId;
  }

  struct Response {
    uint256 createdAt;
    address proposer;
    bytes32 requestId;
    bytes32 disputeId;
    bytes response;
  }

  struct Dispute {
    uint256 createdAt;
    address disputer;
    address proposer;
    bytes32 responseId;
    bytes32 requestId;
    DisputeStatus status;
  }

  enum DisputeStatus {
    None,
    Active,
    Escalated,
    Won,
    Lost,
    NoResolution
  }

  /**
   * @notice  Generates the request ID and initializes the modules for the request
   * @dev     The modules must be real contracts following the IModule interface
   * @param   _request    The request data
   * @return  _requestId  The ID of the request, can be used to propose a response or query results
   */
  function createRequest(IOracle.NewRequest memory _request) external payable returns (bytes32 _requestId);

  /**
   * @notice  Creates multiple requests, the same way as createRequest
   * @param   _requestsData  The array of calldata for each request
   * @return  _batchRequestsIds    The array of request IDs
   */
  function createRequests(IOracle.NewRequest[] calldata _requestsData)
    external
    returns (bytes32[] memory _batchRequestsIds);

  function validModule(bytes32 _requestId, address _module) external view returns (bool _validModule);
  function getDispute(bytes32 _disputeId) external view returns (Dispute memory _dispute);
  function getResponse(bytes32 _responseId) external view returns (Response memory _response);
  function getRequest(bytes32 _requestId) external view returns (Request memory _request);
  function getFullRequest(bytes32 _requestId) external view returns (FullRequest memory _request);
  function disputeOf(bytes32 _requestId) external view returns (bytes32 _disputeId);
  function proposeResponse(bytes32 _requestId, bytes calldata _responseData) external returns (bytes32 _responseId);
  function proposeResponse(
    address _proposer,
    bytes32 _requestId,
    bytes calldata _responseData
  ) external returns (bytes32 _responseId);
  function disputeResponse(bytes32 _requestId, bytes32 _responseId) external returns (bytes32 _disputeId);
  function escalateDispute(bytes32 _disputeId) external;
  function getFinalizedResponse(bytes32 _requestId) external view returns (Response memory _response);
  function getResponseIds(bytes32 _requestId) external view returns (bytes32[] memory _ids);
  function resolveDispute(bytes32 _disputeId) external;
  function updateDisputeStatus(bytes32 _disputeId, DisputeStatus _status) external;
  function listRequests(uint256 _startFrom, uint256 _amount) external view returns (FullRequest[] memory _list);
  function listRequestIds(uint256 _startFrom, uint256 _batchSize) external view returns (bytes32[] memory _list);
  function finalize(bytes32 _requestId, bytes32 _finalizedResponseId) external;
}
