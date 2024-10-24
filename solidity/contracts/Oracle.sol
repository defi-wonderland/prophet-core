// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../interfaces/IOracle.sol';

import {IDisputeModule} from '../interfaces/modules/dispute/IDisputeModule.sol';

import {IFinalityModule} from '../interfaces/modules/finality/IFinalityModule.sol';
import {IRequestModule} from '../interfaces/modules/request/IRequestModule.sol';
import {IResolutionModule} from '../interfaces/modules/resolution/IResolutionModule.sol';
import {IResponseModule} from '../interfaces/modules/response/IResponseModule.sol';
import {ValidatorLib} from '../libraries/ValidatorLib.sol';

contract Oracle is IOracle {
  using ValidatorLib for *;

  /// @inheritdoc IOracle
  mapping(bytes32 _requestId => uint256 _finalizedAt) public finalizedAt;

  /// @inheritdoc IOracle
  mapping(bytes32 _id => uint256 _requestCreatedAt) public requestCreatedAt;

  /// @inheritdoc IOracle
  mapping(bytes32 _id => uint256 _responseCreatedAt) public responseCreatedAt;

  /// @inheritdoc IOracle
  mapping(bytes32 _id => uint256 _disputeCreatedAt) public disputeCreatedAt;

  /// @inheritdoc IOracle
  mapping(bytes32 _responseId => bytes32 _disputeId) public disputeOf;

  /// @inheritdoc IOracle
  mapping(bytes32 _disputeId => DisputeStatus _status) public disputeStatus;

  /// @inheritdoc IOracle
  mapping(uint256 _requestNumber => bytes32 _id) public nonceToRequestId;

  /// @inheritdoc IOracle
  mapping(bytes32 _requestId => bytes32 _finalizedResponseId) public finalizedResponseId;

  /// @inheritdoc IOracle
  mapping(bytes32 _requestId => mapping(address _module => bool _allowed)) public allowedModule;

  /// @inheritdoc IOracle
  mapping(bytes32 _requestId => mapping(address _user => bool _isParticipant)) public isParticipant;

  /**
   * @notice The list of the response ids for each request
   */
  mapping(bytes32 _requestId => bytes _responseIds) internal _responseIds;

  /// @inheritdoc IOracle
  uint256 public totalRequestCount;

  /// @inheritdoc IOracle
  function createRequest(Request calldata _request, bytes32 _ipfsHash) external returns (bytes32 _requestId) {
    _requestId = _createRequest(_request, _ipfsHash);
  }

  /// @inheritdoc IOracle
  function createRequests(
    Request[] calldata _requestsData,
    bytes32[] calldata _ipfsHashes
  ) external returns (bytes32[] memory _batchRequestsIds) {
    uint256 _requestsAmount = _requestsData.length;
    _batchRequestsIds = new bytes32[](_requestsAmount);

    for (uint256 _i = 0; _i < _requestsAmount;) {
      _batchRequestsIds[_i] = _createRequest(_requestsData[_i], _ipfsHashes[_i]);
      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IOracle
  function listRequestIds(uint256 _startFrom, uint256 _batchSize) external view returns (bytes32[] memory _list) {
    uint256 _totalRequestsCount = totalRequestCount;

    // If trying to collect non-existent ids only, return empty array
    if (_startFrom > _totalRequestsCount) {
      return _list;
    }

    if (_batchSize > _totalRequestsCount - _startFrom) {
      _batchSize = _totalRequestsCount - _startFrom;
    }

    _list = new bytes32[](_batchSize);

    uint256 _index;
    while (_index < _batchSize) {
      _list[_index] = nonceToRequestId[_startFrom + _index];

      unchecked {
        ++_index;
      }
    }
  }

  /// @inheritdoc IOracle
  function proposeResponse(
    Request calldata _request,
    Response calldata _response
  ) external returns (bytes32 _responseId) {
    _responseId = ValidatorLib._validateResponse(_request, _response);

    bytes32 _requestId = _response.requestId;

    if (requestCreatedAt[_requestId] == 0) {
      revert Oracle_InvalidRequest();
    }

    // The caller must be the proposer, unless the response is coming from a dispute module
    if (msg.sender != _response.proposer && msg.sender != address(_request.disputeModule)) {
      revert Oracle_InvalidProposer();
    }

    // Can't propose the same response twice
    if (responseCreatedAt[_responseId] != 0) {
      revert Oracle_ResponseAlreadyProposed();
    }

    if (finalizedAt[_requestId] != 0) {
      revert Oracle_AlreadyFinalized(_requestId);
    }
    isParticipant[_requestId][_response.proposer] = true;
    IResponseModule(_request.responseModule).propose(_request, _response, msg.sender);
    _responseIds[_requestId] = abi.encodePacked(_responseIds[_requestId], _responseId);
    responseCreatedAt[_responseId] = block.timestamp;

    emit ResponseProposed(_requestId, _responseId, _response);
  }

  /// @inheritdoc IOracle
  function disputeResponse(
    Request calldata _request,
    Response calldata _response,
    Dispute calldata _dispute
  ) external returns (bytes32 _disputeId) {
    bytes32 _responseId;
    (_responseId, _disputeId) = ValidatorLib._validateResponseAndDispute(_request, _response, _dispute);

    bytes32 _requestId = _dispute.requestId;

    if (responseCreatedAt[_responseId] == 0) {
      revert Oracle_InvalidResponse();
    }

    if (_dispute.proposer != _response.proposer) {
      revert Oracle_InvalidProposer();
    }

    if (_dispute.disputer != msg.sender) {
      revert Oracle_InvalidDisputer();
    }

    if (finalizedAt[_requestId] != 0) {
      revert Oracle_AlreadyFinalized(_requestId);
    }

    if (disputeOf[_responseId] != bytes32(0)) {
      revert Oracle_ResponseAlreadyDisputed(_responseId);
    }
    isParticipant[_requestId][msg.sender] = true;
    disputeStatus[_disputeId] = DisputeStatus.Active;
    disputeOf[_responseId] = _disputeId;
    disputeCreatedAt[_disputeId] = block.timestamp;

    IDisputeModule(_request.disputeModule).disputeResponse(_request, _response, _dispute);

    emit ResponseDisputed(_responseId, _disputeId, _dispute);
  }

  /// @inheritdoc IOracle
  function escalateDispute(Request calldata _request, Response calldata _response, Dispute calldata _dispute) external {
    (bytes32 _responseId, bytes32 _disputeId) = ValidatorLib._validateResponseAndDispute(_request, _response, _dispute);

    if (disputeCreatedAt[_disputeId] == 0) {
      revert Oracle_InvalidDispute();
    }

    if (disputeOf[_responseId] != _disputeId) {
      revert Oracle_InvalidDisputeId(_disputeId);
    }

    if (disputeStatus[_disputeId] != DisputeStatus.Active) {
      revert Oracle_CannotEscalate(_disputeId);
    }

    // Change the dispute status
    disputeStatus[_disputeId] = DisputeStatus.Escalated;

    // Notify the dispute module about the escalation
    IDisputeModule(_request.disputeModule).onDisputeStatusChange(_disputeId, _request, _response, _dispute);

    emit DisputeEscalated(msg.sender, _disputeId, _dispute);

    if (address(_request.resolutionModule) != address(0)) {
      // Initiate the resolution
      IResolutionModule(_request.resolutionModule).startResolution(_disputeId, _request, _response, _dispute);
    }
  }

  /// @inheritdoc IOracle
  function resolveDispute(Request calldata _request, Response calldata _response, Dispute calldata _dispute) external {
    (bytes32 _responseId, bytes32 _disputeId) = ValidatorLib._validateResponseAndDispute(_request, _response, _dispute);

    if (disputeCreatedAt[_disputeId] == 0) {
      revert Oracle_InvalidDispute();
    }

    if (disputeOf[_responseId] != _disputeId) {
      revert Oracle_InvalidDisputeId(_disputeId);
    }

    // Revert if the dispute is not active nor escalated
    DisputeStatus _currentStatus = disputeStatus[_disputeId];
    if (_currentStatus != DisputeStatus.Active && _currentStatus != DisputeStatus.Escalated) {
      revert Oracle_CannotResolve(_disputeId);
    }

    if (address(_request.resolutionModule) == address(0)) {
      revert Oracle_NoResolutionModule(_disputeId);
    }

    IResolutionModule(_request.resolutionModule).resolveDispute(_disputeId, _request, _response, _dispute);

    emit DisputeResolved(_disputeId, _dispute, msg.sender);
  }

  /// @inheritdoc IOracle
  function updateDisputeStatus(
    Request calldata _request,
    Response calldata _response,
    Dispute calldata _dispute,
    DisputeStatus _status
  ) external {
    (bytes32 _responseId, bytes32 _disputeId) = ValidatorLib._validateResponseAndDispute(_request, _response, _dispute);

    if (disputeCreatedAt[_disputeId] == 0) {
      revert Oracle_InvalidDispute();
    }

    if (disputeOf[_responseId] != _disputeId) {
      revert Oracle_InvalidDisputeId(_disputeId);
    }

    if (msg.sender != address(_request.disputeModule) && msg.sender != address(_request.resolutionModule)) {
      revert Oracle_NotDisputeOrResolutionModule(msg.sender);
    }
    disputeStatus[_disputeId] = _status;
    IDisputeModule(_request.disputeModule).onDisputeStatusChange(_disputeId, _request, _response, _dispute);

    emit DisputeStatusUpdated(_disputeId, _dispute, _status);
  }

  /// @inheritdoc IOracle
  function getResponseIds(bytes32 _requestId) public view returns (bytes32[] memory _ids) {
    bytes memory _responses = _responseIds[_requestId];
    uint256 _length = _responses.length / 32;

    assembly {
      for { let _i := 0 } lt(_i, _length) { _i := add(_i, 1) } {
        // Increase the size of the array
        mstore(_ids, add(mload(_ids), 1))

        // Store the response id in the array
        mstore(add(_ids, add(32, mul(_i, 32))), mload(add(_responses, add(32, mul(_i, 32)))))
      }
    }
  }

  /// @inheritdoc IOracle
  function finalize(IOracle.Request calldata _request, IOracle.Response calldata _response) external {
    bytes32 _requestId;
    bytes32 _responseId;

    // Finalizing without a response (by passing a Response with `requestId` == 0x0)
    if (_response.requestId == bytes32(0)) {
      _requestId = _finalizeWithoutResponse(_request);
    } else {
      (_requestId, _responseId) = _finalizeWithResponse(_request, _response);
    }

    if (finalizedAt[_requestId] != 0) {
      revert Oracle_AlreadyFinalized(_requestId);
    }

    finalizedAt[_requestId] = block.timestamp;

    if (address(_request.finalityModule) != address(0)) {
      IFinalityModule(_request.finalityModule).finalizeRequest(_request, _response, msg.sender);
    }

    if (address(_request.resolutionModule) != address(0)) {
      IResolutionModule(_request.resolutionModule).finalizeRequest(_request, _response, msg.sender);
    }

    IDisputeModule(_request.disputeModule).finalizeRequest(_request, _response, msg.sender);
    IResponseModule(_request.responseModule).finalizeRequest(_request, _response, msg.sender);
    IRequestModule(_request.requestModule).finalizeRequest(_request, _response, msg.sender);

    emit OracleRequestFinalized(_requestId, _responseId, msg.sender);
  }

  /**
   * @notice Finalizing a request that either does not have any responses or only has disputed responses
   *
   * @param _request The request to be finalized
   * @return _requestId The id of the finalized request
   */
  function _finalizeWithoutResponse(IOracle.Request calldata _request) internal view returns (bytes32 _requestId) {
    _requestId = ValidatorLib._getId(_request);

    if (requestCreatedAt[_requestId] == 0) {
      revert Oracle_InvalidRequest();
    }

    bytes32[] memory _responses = getResponseIds(_requestId);
    uint256 _responsesAmount = _responses.length;

    if (_responsesAmount != 0) {
      for (uint256 _i = 0; _i < _responsesAmount;) {
        bytes32 _responseId = _responses[_i];
        bytes32 _disputeId = disputeOf[_responseId];
        DisputeStatus _status = disputeStatus[_disputeId];

        // If there is an undisputed response or with a lost dispute, must finalize with it
        if (_status == DisputeStatus.None || _status == DisputeStatus.Lost) {
          revert Oracle_FinalizableResponseExists(_responseId);
        }

        unchecked {
          ++_i;
        }
      }
    }
  }

  /**
   * @notice Finalizing a request with a response
   *
   * @param _request The request to be finalized
   * @param _response The final response
   * @return _requestId The id of the finalized request
   * @return _responseId The id of the final response
   */
  function _finalizeWithResponse(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response
  ) internal returns (bytes32 _requestId, bytes32 _responseId) {
    _responseId = ValidatorLib._validateResponse(_request, _response);

    _requestId = _response.requestId;

    if (responseCreatedAt[_responseId] == 0) {
      revert Oracle_InvalidResponse();
    }

    DisputeStatus _status = disputeStatus[disputeOf[_responseId]];

    if (_status != DisputeStatus.None && _status != DisputeStatus.Lost) {
      revert Oracle_InvalidFinalizedResponse();
    }

    finalizedResponseId[_requestId] = _responseId;
  }

  /**
   * @notice Stores a request in the contract and configures it in the modules
   *
   * @param _request The request to be created
   * @param _ipfsHash The hashed IPFS CID of the metadata json
   * @return _requestId The id of the created request
   */
  function _createRequest(Request memory _request, bytes32 _ipfsHash) internal returns (bytes32 _requestId) {
    uint256 _requestNonce = totalRequestCount++;

    if (_request.nonce == 0) _request.nonce = uint96(_requestNonce);

    if (msg.sender != _request.requester || _requestNonce != _request.nonce) {
      revert Oracle_InvalidRequestBody();
    }

    _requestId = ValidatorLib._getId(_request);
    nonceToRequestId[_requestNonce] = _requestId;
    requestCreatedAt[_requestId] = block.timestamp;

    allowedModule[_requestId][_request.requestModule] = true;
    allowedModule[_requestId][_request.responseModule] = true;
    allowedModule[_requestId][_request.disputeModule] = true;
    allowedModule[_requestId][_request.resolutionModule] = true;
    allowedModule[_requestId][_request.finalityModule] = true;

    isParticipant[_requestId][msg.sender] = true;

    IRequestModule(_request.requestModule).createRequest(_requestId, _request.requestModuleData, msg.sender);

    emit RequestCreated(_requestId, _request, _ipfsHash);
  }
}
