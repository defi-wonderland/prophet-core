// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRequestModule} from './modules/request/IRequestModule.sol';
import {IResponseModule} from './modules/response/IResponseModule.sol';
import {IDisputeModule} from './modules/dispute/IDisputeModule.sol';
import {IResolutionModule} from './modules/resolution/IResolutionModule.sol';
import {IFinalityModule} from './modules/finality/IFinalityModule.sol';

/**
 * @title Oracle
 * @notice The main contract storing requests, responses and disputes, and routing the calls to the modules.
 */
interface IOracle {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a request is created
   * @param _requestId The id of the created request
   * @param _requester The address of the user who created the request
   */
  event RequestCreated(bytes32 indexed _requestId, address indexed _requester);

  /**
   * @notice Emitted when a response is proposed
   * @param _requestId The id of the request
   * @param _proposer The address of the user who proposed the response
   * @param _responseId The id of the proposed response
   */
  event ResponseProposed(bytes32 indexed _requestId, address indexed _proposer, bytes32 indexed _responseId);

  /**
   * @notice Emitted when a response is disputed
   * @param _disputer The address of the user who started the dispute
   * @param _responseId The id of the response being disputed
   * @param _disputeId The id of the dispute
   */
  event ResponseDisputed(address indexed _disputer, bytes32 indexed _responseId, bytes32 indexed _disputeId);

  /**
   * @notice Emitted when a request is finalized
   * @param _requestId The id of the request being finalized
   * @param _caller The address of the user who finalized the request
   */
  event OracleRequestFinalized(bytes32 indexed _requestId, address indexed _caller);

  /**
   * @notice Emitted when a dispute is escalated
   * @param _caller The address of the user who escalated the dispute
   * @param _disputeId The id of the dispute being escalated
   */
  event DisputeEscalated(address indexed _caller, bytes32 indexed _disputeId);

  /**
   * @notice Emitted when a dispute's status changes
   * @param _disputeId The id of the dispute
   * @param _status The new dispute status
   */
  event DisputeStatusUpdated(bytes32 indexed _disputeId, DisputeStatus _status);

  /**
   * @notice Emitted when a dispute is resolved
   * @param _caller The address of the user who resolved the dispute
   * @param _disputeId The id of the dispute being resolved
   */
  event DisputeResolved(address indexed _caller, bytes32 indexed _disputeId);

  /**
   * @notice Emitted when a response is deleted
   * @param _requestId The id of the request
   * @param _caller The address of the user who deleted the response
   * @param _responseId The id of the deleted response
   */
  event ResponseDeleted(bytes32 indexed _requestId, address indexed _caller, bytes32 indexed _responseId);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when an unauthorized caller is trying to change a dispute's status
   * @param _caller The caller of the function
   */
  error Oracle_NotResolutionModule(address _caller);

  /**
   * @notice Thrown when an unauthorized caller is trying to propose a response
   * @param _caller The caller of the function
   */
  error Oracle_NotDisputeModule(address _caller);

  /**
   * @notice Thrown when trying to resolve a dispute of a request without resolution module
   * @param _disputeId The id of the dispute being
   */
  error Oracle_NoResolutionModule(bytes32 _disputeId);

  /**
   * @notice Thrown when disputing a response that is already disputed
   * @param _responseId The id of the response being disputed
   */
  error Oracle_ResponseAlreadyDisputed(bytes32 _responseId);

  /**
   * @notice Thrown when trying to dispute or finalize a request that is already finalized
   * @param _requestId The id of the request
   */
  error Oracle_AlreadyFinalized(bytes32 _requestId);

  /**
   * @notice Thrown when trying to finalize a request with an invalid response
   * @param _responseId The id of the response
   */
  error Oracle_InvalidFinalizedResponse(bytes32 _responseId);

  /**
   * @notice Thrown when trying to resolve or escalate an invalid dispute
   * @param _disputeId The id of the dispute
   */
  error Oracle_InvalidDisputeId(bytes32 _disputeId);

  /**
   * @notice Thrown when trying to dispute an invalid response
   * @param _responseId The id of the response being disputed
   */
  error Oracle_InvalidResponseId(bytes32 _responseId);

  /**
   * @notice Thrown when trying to propose a response to an invalid request
   * @param _requestId The id of the request
   */
  error Oracle_InvalidRequestId(bytes32 _requestId);

  /**
   * @notice Thrown when trying to escalate a dispute that's not in the active state
   * @param _disputeId The id of the dispute
   */
  error Oracle_CannotEscalate(bytes32 _disputeId);

  /**
   * @notice Thrown when trying to resolve a dispute that's not in the active nor escalated state
   * @param _disputeId The id of the dispute
   */
  error Oracle_CannotResolve(bytes32 _disputeId);

  /**
   * @notice Thrown when trying to delete a disputed response
   * @param _responseId The id of the response being deleted
   */
  error Oracle_CannotDeleteWhileDisputing(bytes32 _responseId);

  /**
   * @notice Thrown when an unauthorized caller is trying to delete a response
   * @param _caller The caller of the function
   * @param _responseId The id of the response being deleted
   */
  error Oracle_CannotDeleteInvalidProposer(address _caller, bytes32 _responseId);

  /**
   * @notice Thrown when a module tries to tamper with the address of the user
   */
  error Oracle_CannotTamperParticipant();

  /*///////////////////////////////////////////////////////////////
                              ENUMS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice All available statuses a dispute can have
   */
  enum DisputeStatus {
    None,
    Active,
    Escalated,
    Won,
    Lost,
    NoResolution
  }

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Request as stored in the oracle
   * @param ipfsHash The hash of the CID from IPFS
   * @param requestModule The address of the request module
   * @param responseModule The address of the response module
   * @param disputeModule The address of the dispute module
   * @param resolutionModule The address of the resolution module
   * @param finalityModule The address of the finality module
   * @param requester The address of the user who created the request
   * @param nonce The nonce of the request
   * @param createdAt The timestamp of the request creation
   * @param finalizedAt The timestamp of the request finalization
   */
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
    uint256 finalizedAt;
  }

  /**
   * @notice Request as sent by requester
   * @param requestModuleData The parameters for the request module
   * @param responseModuleData The parameters for the response module
   * @param disputeModuleData The parameters for the dispute module
   * @param resolutionModuleData The parameters for the resolution module
   * @param finalityModuleData The parameters for the finality module
   * @param ipfsHash The hash of the CID from IPFS
   * @param requestModule The address of the request module
   * @param responseModule The address of the response module
   * @param disputeModule The address of the dispute module
   * @param resolutionModule The address of the resolution module
   * @param finalityModule The address of the finality module
   */
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

  /**
   * @notice The full request struct including all available information about a request
   * @param requestModuleData The parameters for the request module
   * @param responseModuleData The parameters for the response module
   * @param disputeModuleData The parameters for the dispute module
   * @param resolutionModuleData The parameters for the resolution module
   * @param finalityModuleData The parameters for the finality module
   * @param ipfsHash The hash of the CID from IPFS
   * @param requestModule The address of the request module
   * @param responseModule The address of the response module
   * @param disputeModule The address of the dispute module
   * @param resolutionModule The address of the resolution module
   * @param finalityModule The address of the finality module
   * @param requester The address of the user who created the request
   * @param nonce The nonce of the request
   * @param createdAt The timestamp of the request creation
   * @param finalizedAt The timestamp of the request finalization
   * @param requestId The id of the request
   */
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
    uint256 finalizedAt;
    bytes32 requestId;
  }

  /**
   * @notice The response struct
   * @param createdAt The timestamp of the response creation
   * @param proposer The address of the user who proposed the response
   * @param requestId The id of the request this response is proposed for
   * @param disputeId The id of the dispute if the response is disputed
   * @param response The encoded data of the response
   */
  struct Response {
    uint256 createdAt;
    address proposer;
    bytes32 requestId;
    bytes32 disputeId;
    bytes response;
  }

  /**
   * @notice The dispute struct
   * @param createdAt The timestamp of the dispute creation
   * @param disputer The address of the user who started the dispute
   * @param proposer The address of the user who proposed the response
   * @param responseId The id of the response being disputed
   * @param requestId The id of the request this dispute is related to
   * @param status The status of the dispute
   */
  struct Dispute {
    uint256 createdAt;
    address disputer;
    address proposer;
    bytes32 responseId;
    bytes32 requestId;
    DisputeStatus status;
  }

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the dispute id for a given response
   * @param _responseId The response id to get the dispute for
   * @return _disputeId The id of the dispute associated with the given response
   */
  function disputeOf(bytes32 _responseId) external view returns (bytes32 _disputeId);

  /**
   * @notice Returns the total number of requests stored in the oracle
   * @return _count The total number of requests
   */
  function totalRequestCount() external view returns (uint256 _count);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Generates the request ID and initializes the modules for the request
   * @dev The modules must be real contracts following the IModule interface
   * @param _request The request data
   * @return _requestId The id of the request, can be used to propose a response or query results
   */
  function createRequest(IOracle.NewRequest memory _request) external returns (bytes32 _requestId);

  /**
   * @notice Creates multiple requests, the same way as createRequest
   * @param _requestsData The array of calldata for each request
   * @return _batchRequestsIds The array of request IDs
   */
  function createRequests(IOracle.NewRequest[] calldata _requestsData)
    external
    returns (bytes32[] memory _batchRequestsIds);

  /**
   * @notice Returns the list of requests
   * @param _startFrom The index to start from
   * @param _batchSize The number of requests to return
   * @return _list The list of requests
   */
  function listRequests(uint256 _startFrom, uint256 _batchSize) external view returns (FullRequest[] memory _list);

  /**
   * @notice Returns the list of request IDs
   * @param _startFrom The index to start from
   * @param _batchSize The number of requests to return
   * @return _list The list of request IDs
   */
  function listRequestIds(uint256 _startFrom, uint256 _batchSize) external view returns (bytes32[] memory _list);

  /**
   * @notice Fetches a response
   * @param _responseId The id of the response
   * @return _response The response data
   */
  function getResponse(bytes32 _responseId) external view returns (Response memory _response);

  /**
   * @notice Returns a request id
   * @param _nonce The nonce of the request
   * @return _requestId The id of the request
   */
  function getRequestId(uint256 _nonce) external view returns (bytes32 _requestId);

  /**
   * @notice Returns a request
   * @param _nonce The nonce of the request
   * @return _request The request data
   */
  function getRequestByNonce(uint256 _nonce) external view returns (Request memory _request);

  /**
   * @notice Returns a request
   * @param _requestId The id of the request
   * @return _request The request data
   */
  function getRequest(bytes32 _requestId) external view returns (Request memory _request);

  /**
   * @notice Returns a full request
   * @param _requestId The id of the request
   * @return _request The request data
   */
  function getFullRequest(bytes32 _requestId) external view returns (FullRequest memory _request);

  /**
   * @notice Returns a dispute
   * @param _disputeId The id of the dispute
   * @return _dispute The dispute data
   */
  function getDispute(bytes32 _disputeId) external view returns (Dispute memory _dispute);

  /**
   * @notice Creates a new response for a given request
   * @param _requestId The id of the request
   * @param _responseData The response data
   * @return _responseId The id of the created response
   */
  function proposeResponse(bytes32 _requestId, bytes calldata _responseData) external returns (bytes32 _responseId);

  /**
   * @notice Creates a new response for a given request
   * @dev Only callable by the dispute module of the request
   * @param _proposer The address of the user proposing the response
   * @param _requestId The id of the request
   * @param _responseData The response data
   * @return _responseId The id of the created response
   */
  function proposeResponse(
    address _proposer,
    bytes32 _requestId,
    bytes calldata _responseData
  ) external returns (bytes32 _responseId);

  /**
   * @notice Deletes a response
   * @param _responseId The id of the response being deleted
   */
  function deleteResponse(bytes32 _responseId) external;

  /**
   * @notice Starts the process of disputing a response
   * @dev If pre-dispute modules are being used, the returned dispute
   * from `disputeModule.disputeResponse` may have a status other than `Active`,
   * in which case the dispute is considered resolved and the dispute status updated.
   * @param _requestId The id of the request which was responded
   * @param _responseId The id of the response being disputed
   */
  function disputeResponse(bytes32 _requestId, bytes32 _responseId) external returns (bytes32 _disputeId);

  /**
   * @notice Escalates a dispute, sending it to the resolution module
   * @param _disputeId The id of the dispute to escalate
   */
  function escalateDispute(bytes32 _disputeId) external;

  /**
   * @notice Resolves a dispute
   * @param _disputeId The id of the dispute to resolve
   */
  function resolveDispute(bytes32 _disputeId) external;

  /**
   * @notice Updates the status of a dispute
   * @param _disputeId The id of the dispute to update
   * @param _status The new status of the dispute
   */
  function updateDisputeStatus(bytes32 _disputeId, DisputeStatus _status) external;

  /**
   * @notice Checks if the given address is a module used in the request
   * @param _requestId The id of the request
   * @param _module The address to check
   * @return _allowedModule If the module is a part of the request
   */
  function allowedModule(bytes32 _requestId, address _module) external view returns (bool _allowedModule);

  /**
   * @notice Checks if the given address is participating in a specific request
   * @param _requestId The id of the request
   * @param _user The address to check
   * @return _isParticipant If the user is a participant of the request
   */
  function isParticipant(bytes32 _requestId, address _user) external view returns (bool _isParticipant);

  /**
   * @notice Returns the finalized response ID for a given request
   * @param _requestId The id of the request
   * @return _finalizedResponseId The ID of the finalized response
   */
  function getFinalizedResponseId(bytes32 _requestId) external view returns (bytes32 _finalizedResponseId);

  /**
   * @notice Returns the finalized response for a given request
   * @param _requestId The id of the request
   * @return _response The finalized response
   */
  function getFinalizedResponse(bytes32 _requestId) external view returns (Response memory _response);

  /**
   * @notice Returns the ids of the responses for a given request
   * @param _requestId The id of the request
   * @return _ids The ids of the responses
   */
  function getResponseIds(bytes32 _requestId) external view returns (bytes32[] memory _ids);

  /**
   * @notice Finalizes a request
   * @param _requestId The id of the request to finalize
   * @param _finalizedResponseId The id of the response to finalize the request with
   */
  function finalize(bytes32 _requestId, bytes32 _finalizedResponseId) external;

  /**
   * @notice Finalizes a request without a valid response
   * @param _requestId The id of the request to finalize
   */
  function finalize(bytes32 _requestId) external;
}
