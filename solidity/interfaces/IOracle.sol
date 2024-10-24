// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAccessController} from './IAccessController.sol';

/**
 * @title Oracle
 * @notice The main contract storing requests, responses and disputes, and routing the calls to the modules.
 */
interface IOracle is IAccessController {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a request is created
   * @param _requestId The id of the created request
   * @param _request The request that has been created
   * @param _ipfsHash The hashed IPFS CID of the metadata json
   */
  event RequestCreated(bytes32 indexed _requestId, Request _request, bytes32 _ipfsHash);

  /**
   * @notice Emitted when a response is proposed
   * @param _requestId The id of the request
   * @param _responseId The id of the proposed response
   * @param _response The response that has been proposed
   */
  event ResponseProposed(bytes32 indexed _requestId, bytes32 indexed _responseId, Response _response);

  /**
   * @notice Emitted when a response is disputed
   * @param _responseId The id of the response being disputed
   * @param _disputeId The id of the dispute
   * @param _dispute The dispute that has been created
   */
  event ResponseDisputed(bytes32 indexed _responseId, bytes32 indexed _disputeId, Dispute _dispute);

  /**
   * @notice Emitted when a request is finalized
   * @param _requestId The id of the request being finalized
   * @param _responseId The id of the final response, may be empty
   */
  event OracleRequestFinalized(bytes32 indexed _requestId, bytes32 indexed _responseId);

  /**
   * @notice Emitted when a dispute is escalated
   * @param _caller The address of the user who escalated the dispute
   * @param _disputeId The id of the dispute being escalated
   * @param _dispute The dispute that is being escalated
   */
  event DisputeEscalated(address indexed _caller, bytes32 indexed _disputeId, Dispute _dispute);

  /**
   * @notice Emitted when a dispute's status changes
   * @param _disputeId The id of the dispute
   * @param _dispute The dispute that is being updated
   * @param _status The new dispute status
   */
  event DisputeStatusUpdated(bytes32 indexed _disputeId, Dispute _dispute, DisputeStatus _status);

  /**
   * @notice Emitted when a dispute is resolved
   * @param _disputeId The id of the dispute being resolved
   * @param _dispute The dispute that is being updated
   */
  event DisputeResolved(bytes32 indexed _disputeId, Dispute _dispute);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when an unauthorized caller is trying to change a dispute's status
   * @param _caller The caller of the function
   */
  error Oracle_NotDisputeOrResolutionModule(address _caller);

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
   */
  error Oracle_InvalidFinalizedResponse();

  /**
   * @notice Thrown when trying to finalize a request without a response while there is, in fact, a response
   * @param _responseId The id of the response that would be suitable for finalization
   */
  error Oracle_FinalizableResponseExists(bytes32 _responseId);

  /**
   * @notice Thrown when trying to resolve or escalate an invalid dispute
   * @param _disputeId The id of the dispute
   */
  error Oracle_InvalidDisputeId(bytes32 _disputeId);

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
   * @notice Thrown when trying to create a request with invalid parameters
   */
  error Oracle_InvalidRequestBody();

  /**
   * @notice Thrown when trying to propose a response with invalid parameters
   */
  error Oracle_InvalidResponseBody();

  /**
   * @notice Thrown when trying to create a dispute with invalid parameters
   */
  error Oracle_InvalidDisputeBody();

  /**
   * @notice Thrown when the request provided does not exist
   */
  error Oracle_InvalidRequest();

  /**
   * @notice Thrown when the response provided does not exist
   */
  error Oracle_InvalidResponse();

  /**
   * @notice Thrown when the dispute provided does not exist
   */
  error Oracle_InvalidDispute();

  /**
   * @notice Thrown when response has been already proposed
   */
  error Oracle_ResponseAlreadyProposed();

  /**
   * @notice Thrown when the proposer is invalid
   */
  error Oracle_InvalidProposer();

  /**
   * @notice Thrown when the disputer is invalid
   */
  error Oracle_InvalidDisputer();

  /*///////////////////////////////////////////////////////////////
                              ENUMS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice All available statuses a dispute can have
   */
  enum DisputeStatus {
    None, // The dispute has not been started yet
    Active, // The dispute is active and can be escalated or resolved
    Escalated, // The dispute is being resolved by the resolution module
    Won, // The disputer has won the dispute
    Lost, // The disputer has lost the dispute
    NoResolution // The dispute was inconclusive

  }

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Request as stored in the oracle
   * @param requestModule The address of the request module
   * @param responseModule The address of the response module
   * @param disputeModule The address of the dispute module
   * @param resolutionModule The address of the resolution module
   * @param finalityModule The address of the finality module
   * @param accessControlModule The address of the access control module
   * @param requestModuleData The parameters for the request module
   * @param responseModuleData The parameters for the response module
   * @param disputeModuleData The parameters for the dispute module
   * @param resolutionModuleData The parameters for the resolution module
   * @param finalityModuleData The parameters for the finality module
   * @param requester The address of the user who created the request
   * @param nonce The nonce of the request
   */
  struct Request {
    uint96 nonce;
    address requester;
    address requestModule;
    address responseModule;
    address disputeModule;
    address resolutionModule;
    address finalityModule;
    address accessControlModule;
    bytes requestModuleData;
    bytes responseModuleData;
    bytes disputeModuleData;
    bytes resolutionModuleData;
    bytes finalityModuleData;
  }

  /**
   * @notice The response struct
   * @param proposer The address of the user who proposed the response
   * @param requestId The id of the request this response is proposed for
   * @param response The encoded data of the response
   */
  struct Response {
    address proposer;
    bytes32 requestId;
    bytes response;
  }

  /**
   * @notice The dispute struct
   * @param disputer The address of the user who started the dispute
   * @param proposer The address of the user who proposed the response
   * @param responseId The id of the response being disputed
   * @param requestId The id of the request this dispute is related to
   */
  struct Dispute {
    address disputer;
    address proposer;
    bytes32 responseId;
    bytes32 requestId;
  }

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The block's timestamp at which a request was finalized
   *
   * @param _requestId The request id
   * @return _finalizedAt The block's timestamp
   */
  function finalizedAt(bytes32 _requestId) external view returns (uint256 _finalizedAt);

  /**
   * @notice The block's timestamp at which a request was created
   *
   * @param _id The request id
   * @return _requestCreatedAt The block's timestamp
   */
  function requestCreatedAt(bytes32 _id) external view returns (uint256 _requestCreatedAt);

  /**
   * @notice The block's timestamp at which a response was created
   *
   * @param _id The response id
   * @return _responseCreatedAt The block's timestamp
   */
  function responseCreatedAt(bytes32 _id) external view returns (uint256 _responseCreatedAt);

  /**
   * @notice The block's timestamp at which a dispute was created
   *
   * @param _id The dispute id
   * @return _disputeCreatedAt The block's timestamp
   */
  function disputeCreatedAt(bytes32 _id) external view returns (uint256 _disputeCreatedAt);

  /**
   * @notice Returns the dispute id for a given response
   *
   * @param _responseId The response id to get the dispute for
   * @return _disputeId The id of the dispute associated with the given response
   */
  function disputeOf(bytes32 _responseId) external view returns (bytes32 _disputeId);

  /**
   * @notice Returns the status of a dispute
   *
   * @param _disputeId The id of the dispute
   * @return _status The status of the dispute
   */
  function disputeStatus(bytes32 _disputeId) external view returns (DisputeStatus _status);

  /**
   * @notice The id of each request in chronological order
   *
   * @param _nonce The nonce of the request
   * @return _requestId The id of the request
   */
  function nonceToRequestId(uint256 _nonce) external view returns (bytes32 _requestId);

  /**
   * @notice Returns the finalized response ID for a given request
   *
   * @param _requestId The id of the request
   * @return _finalizedResponseId The id of the finalized response
   */
  function finalizedResponseId(bytes32 _requestId) external view returns (bytes32 _finalizedResponseId);

  /**
   * @notice Checks if the given address is a module used in the request
   *
   * @param _requestId The id of the request
   * @param _module The address to check
   * @return _allowed If the module is a part of the request
   */
  function allowedModule(bytes32 _requestId, address _module) external view returns (bool _allowed);

  /**
   * @notice Checks if the given address is participating in a specific request
   *
   * @param _requestId The id of the request
   * @param _user The address to check
   * @return _isParticipant If the user is a participant of the request
   */
  function isParticipant(bytes32 _requestId, address _user) external view returns (bool _isParticipant);

  /**
   * @notice Checks if the given address approved the access control module
   *
   * @param _user The address to check
   * @param _accessControlModule The address of the access control module
   * @return _approved If the user approved the access control module
   */
  function isAccessControlApproved(address _user, address _accessControlModule) external view returns (bool _approved);

  /**
   * @notice Returns the total number of requests stored in the oracle
   *
   * @return _count The total number of requests
   */
  function totalRequestCount() external view returns (uint256 _count);

  /**
   * @notice Returns the list of request IDs
   *
   * @param _startFrom The index to start from
   * @param _batchSize The number of requests to return
   * @return _list The list of request IDs
   */
  function listRequestIds(uint256 _startFrom, uint256 _batchSize) external view returns (bytes32[] memory _list);

  /**
   * @notice Returns the ids of the responses for a given request
   *
   * @param _requestId The id of the request
   * @return _ids The ids of the responses
   */
  function getResponseIds(bytes32 _requestId) external view returns (bytes32[] memory _ids);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Generates the request ID and initializes the modules for the request
   *
   * @dev The modules must be real contracts following the IModule interface
   * @param _request The request data
   * @param _ipfsHash The hashed IPFS CID of the metadata json
   * @param _accessControl The access control data
   * @return _requestId The id of the request, can be used to propose a response or query results
   */
  function createRequest(
    Request memory _request,
    bytes32 _ipfsHash,
    AccessControl calldata _accessControl
  ) external returns (bytes32 _requestId);

  /**
   * @notice Creates multiple requests, the same way as createRequest
   *
   * @param _requestsData The array of calldata for each request
   * @return _batchRequestsIds The array of request IDs
   * @param _ipfsHashes The array of hashed IPFS CIDs of the metadata files
   * @param _accessControl The array of access control datas
   */
  function createRequests(
    Request[] calldata _requestsData,
    bytes32[] calldata _ipfsHashes,
    AccessControl[] calldata _accessControl
  ) external returns (bytes32[] memory _batchRequestsIds);

  /**
   * @notice Creates a new response for a given request
   *
   * @param _request The request to create a response for
   * @param _response The response data
   * @param _accessControl The access control data
   * @return _responseId The id of the created response
   */
  function proposeResponse(
    Request calldata _request,
    Response calldata _response,
    AccessControl calldata _accessControl
  ) external returns (bytes32 _responseId);

  /**
   * @notice Starts the process of disputing a response
   *
   * @param _request The request
   * @param _response The response to dispute
   * @param _dispute The dispute data
   * @param _accessControl The access control data
   * @return _disputeId The id of the created dispute
   */
  function disputeResponse(
    Request calldata _request,
    Response calldata _response,
    Dispute calldata _dispute,
    AccessControl calldata _accessControl
  ) external returns (bytes32 _disputeId);

  /**
   * @notice Escalates a dispute, sending it to the resolution module
   *
   * @param _request The request
   * @param _response The disputed response
   * @param _dispute The dispute that is being escalated
   * @param _accessControl The access control data
   */
  function escalateDispute(
    Request calldata _request,
    Response calldata _response,
    Dispute calldata _dispute,
    AccessControl calldata _accessControl
  ) external;

  /**
   * @notice Resolves a dispute
   *
   * @param _request The request
   * @param _response The disputed response
   * @param _dispute The dispute that is being resolved
   * @param _accessControl The access control data
   */
  function resolveDispute(
    Request calldata _request,
    Response calldata _response,
    Dispute calldata _dispute,
    AccessControl calldata _accessControl
  ) external;

  /**
   * @notice Updates the status of a dispute
   *
   * @param _request The request
   * @param _response The disputed response
   * @param _dispute The dispute that is being updated
   * @param _status The new status of the dispute
   * @param _accessControl The access control data
   */
  function updateDisputeStatus(
    Request calldata _request,
    Response calldata _response,
    Dispute calldata _dispute,
    DisputeStatus _status,
    AccessControl calldata _accessControl
  ) external;

  /**
   * @notice Finalizes the request and executes the post-request logic on the modules
   *
   * @dev In case of a request with no responses, an response with am empty `requestId` is expected
   * @param _request The request being finalized
   * @param _response The final response
   * @param _accessControl The access control data
   */
  function finalize(
    Request calldata _request,
    Response calldata _response,
    AccessControl calldata _accessControl
  ) external;
}
