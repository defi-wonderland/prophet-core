// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IRequestModule} from '@interfaces/IRequestModule.sol';
import {IResponseModule} from '@interfaces/IResponseModule.sol';
import {IDisputeModule} from '@interfaces/IDisputeModule.sol';
import {IResolutionModule} from '@interfaces/IResolutionModule.sol';
import {IFinalityModule} from '@interfaces/IFinalityModule.sol';
import {IAccountingExtension} from '@interfaces/IAccountingExtension.sol';

interface IOracle {
  /// @notice Thrown when a proposer is not allowed to propose a response
  error Oracle_CannotPropose(bytes32 _requestId, address _proposer);

  /// @notice Thrown when a disputer is not allowed to dispute a response
  error Oracle_CannotDispute(bytes32 _requestId, address _proposer);

  /// @notice Thrown when an extension is not set for the given request
  error Oracle_NoExtensionSet(bytes32 _requestId);

  /// @notice Thrown when the caller of the slash() function is not the DisputeModule
  error Oracle_NotResolutionModule(address _caller);

  error Oracle_ResponseAlreadyDisputed(bytes32 _responseId);

  struct Request {
    bytes requestModuleData;
    bytes responseModuleData;
    bytes disputeModuleData;
    bytes resolutionModuleData;
    bytes finalityModuleData;
    bytes32 finalizedResponseId;
    IRequestModule requestModule;
    IResponseModule responseModule;
    IDisputeModule disputeModule;
    IResolutionModule resolutionModule;
    IFinalityModule finalityModule;
    address requester;
    uint256 nonce;
  }

  struct Response {
    address proposer;
    bytes32 requestId;
    bytes32 disputeId;
    bytes response;
    bool finalized;
  }

  struct Dispute {
    address disputer;
    address proposer;
    bytes32 responseId;
    bytes32 requestId;
    DisputeStatus status;
  }

  enum DisputeStatus {
    None,
    Active,
    Won,
    Lost
  }

  /**
   * @notice  Generates the request ID and initializes the modules for the request
   * @dev     The modules must be real contracts following the IModule interface
   * @param   _request    The request data
   * @return  _requestId  The ID of the request, can be used to propose a response or query results
   */
  function createRequest(IOracle.Request memory _request) external payable returns (bytes32 _requestId);

  /**
   * @notice  Creates multiple requests, the same way as createRequest
   * @param   _requestsData  The array of calldata for each request
   * @return  _requestIds    The array of request IDs
   */
  function createRequests(bytes[] calldata _requestsData) external returns (bytes32[] memory _requestIds);

  function validModule(bytes32 _requestId, address _module) external view returns (bool _validModule);
  function getDispute(bytes32 _disputeId) external view returns (Dispute memory _dispute);
  function getResponse(bytes32 _responseId) external view returns (Response memory _response);
  function getRequest(bytes32 _requestId) external view returns (Request memory _request);
  function proposeResponse(bytes32 _requestId, bytes calldata _responseData) external returns (bytes32 _responseId);
  function disputeResponse(bytes32 _requestId, bytes32 _responseId) external returns (bytes32 _disputeId);
  function canPropose(bytes32 _requestId, address _proposer) external returns (bool _canPropose);
  function canDispute(bytes32 _requestId, address _disputer) external returns (bool _canDispute);
  function getFinalizedResponse(bytes32 _requestId) external view returns (Response memory _response);
  function getResponseIds(bytes32 _requestId) external view returns (bytes32[] memory _ids);
  function updateDisputeStatus(bytes32 _disputeId, DisputeStatus _status) external;
}
