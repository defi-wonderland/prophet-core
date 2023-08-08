// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '../interfaces/IOracle.sol';
import {Subset} from './libraries/Subset.sol';

contract Oracle is IOracle {
  using Subset for mapping(uint256 => bytes32);

  mapping(bytes32 _responseId => bytes32 _disputeId) public disputeOf;

  mapping(bytes32 _requestId => Request) internal _requests;

  mapping(bytes32 _responseId => Response) internal _responses;
  mapping(bytes32 _requestId => bytes32[] _responseId) internal _responseIds;

  mapping(bytes32 _requestId => Response) internal _finalizedResponses;

  mapping(bytes32 _disputeId => Dispute) internal _disputes;

  mapping(uint256 _requestNumber => bytes32 _id) internal _requestIds;

  uint256 internal _responseNonce;

  uint256 public totalRequestCount;

  function createRequest(NewRequest memory _request) external payable returns (bytes32 _requestId) {
    _requestId = _createRequest(_request);
  }

  function createRequests(NewRequest[] calldata _requestsData) external returns (bytes32[] memory _batchRequestsIds) {
    uint256 _requestsAmount = _requestsData.length;
    _batchRequestsIds = new bytes32[](_requestsAmount);

    for (uint256 _i = 0; _i < _requestsAmount;) {
      _batchRequestsIds[_i] = _createRequest(_requestsData[_i]);
      unchecked {
        ++_i;
      }
    }
  }

  function listRequests(uint256 _startFrom, uint256 _batchSize) external view returns (FullRequest[] memory _list) {
    uint256 _totalRequestsCount = totalRequestCount;

    // If trying to collect unexisting requests only, return empty array
    if (_startFrom > _totalRequestsCount) {
      return _list;
    }

    if (_batchSize > _totalRequestsCount - _startFrom) {
      _batchSize = _totalRequestsCount - _startFrom;
    }

    _list = new FullRequest[](_batchSize);

    uint256 _index;
    while (_index < _batchSize) {
      bytes32 _requestId = _requestIds[_startFrom + _index];

      _list[_index] = _getRequest(_requestId);

      unchecked {
        ++_index;
      }
    }

    return _list;
  }

  function listRequestIds(uint256 _startFrom, uint256 _batchSize) external view returns (bytes32[] memory _list) {
    return _requestIds.getSubset(_startFrom, _batchSize, totalRequestCount);
  }

  function getResponse(bytes32 _responseId) external view returns (Response memory _response) {
    _response = _responses[_responseId];
  }

  function getRequest(bytes32 _requestId) external view returns (Request memory _request) {
    _request = _requests[_requestId];
  }

  function getFullRequest(bytes32 _requestId) external view returns (FullRequest memory _request) {
    _request = _getRequest(_requestId);
  }

  function getDispute(bytes32 _disputeId) external view returns (Dispute memory _dispute) {
    _dispute = _disputes[_disputeId];
  }

  function proposeResponse(bytes32 _requestId, bytes calldata _responseData) external returns (bytes32 _responseId) {
    Request memory _request = _requests[_requestId];
    if (_request.createdAt == 0) revert Oracle_InvalidRequestId(_requestId);
    _responseId = _proposeResponse(msg.sender, _requestId, _request, _responseData);
  }

  function proposeResponse(
    address _proposer,
    bytes32 _requestId,
    bytes calldata _responseData
  ) external returns (bytes32 _responseId) {
    Request memory _request = _requests[_requestId];
    if (msg.sender != address(_request.disputeModule)) revert Oracle_NotDisputeModule(msg.sender);
    _responseId = _proposeResponse(_proposer, _requestId, _request, _responseData);
  }

  function _proposeResponse(
    address _proposer,
    bytes32 _requestId,
    Request memory _request,
    bytes calldata _responseData
  ) internal returns (bytes32 _responseId) {
    _responseId = keccak256(abi.encodePacked(_proposer, address(this), _requestId, _responseNonce++));
    _responses[_responseId] = _request.responseModule.propose(_requestId, _proposer, _responseData);
    _responseIds[_requestId].push(_responseId);
  }

  function disputeResponse(bytes32 _requestId, bytes32 _responseId) external returns (bytes32 _disputeId) {
    if (disputeOf[_responseId] != bytes32(0)) revert Oracle_ResponseAlreadyDisputed(_responseId);
    Request memory _request = _requests[_requestId];
    Response memory _response = _responses[_responseId];

    if (_response.requestId != _requestId || _response.createdAt == 0) revert Oracle_InvalidResponseId(_responseId);

    if (_finalizedResponses[_requestId].createdAt != 0) revert Oracle_AlreadyFinalized(_responseId);
    // Collision avoided -> this user disputes the _responseId from the _requestId
    // -> if trying to redispute, disputeOf isn't empty anymore
    _disputeId = keccak256(abi.encodePacked(msg.sender, _requestId, _responseId));
    _disputes[_disputeId] =
      _request.disputeModule.disputeResponse(_requestId, _responseId, msg.sender, _responses[_responseId].proposer);
    disputeOf[_responseId] = _disputeId;
  }

  function escalateDispute(bytes32 _disputeId) external {
    Dispute memory _dispute = _disputes[_disputeId];

    if (_dispute.createdAt == 0) revert Oracle_InvalidDisputeId(_disputeId);
    if (_dispute.status != DisputeStatus.Active) revert Oracle_CannotEscalate(_disputeId);

    // Change the dispute status
    _dispute.status = DisputeStatus.Escalated;
    _disputes[_disputeId] = _dispute;

    Request memory _request = _requests[_dispute.requestId];

    // Notify the dispute module about the escalation
    _request.disputeModule.disputeEscalated(_disputeId);

    if (address(_request.resolutionModule) != address(0)) {
      // Initiate the resolution
      _request.resolutionModule.startResolution(_disputeId);
    }
  }

  function resolveDispute(bytes32 _disputeId) external {
    Dispute memory _dispute = _disputes[_disputeId];

    if (_dispute.createdAt == 0) revert Oracle_InvalidDisputeId(_disputeId);
    // Revert if the dispute is not active nor escalated
    unchecked {
      if (uint256(_dispute.status) - 1 > 1) revert Oracle_CannotResolve(_disputeId);
    }

    Request memory _request = _requests[_dispute.requestId];
    if (address(_request.resolutionModule) == address(0)) revert Oracle_NoResolutionModule(_disputeId);

    _request.resolutionModule.resolveDispute(_disputeId);
  }

  function updateDisputeStatus(bytes32 _disputeId, DisputeStatus _status) external {
    Dispute storage _dispute = _disputes[_disputeId];
    Request memory _request = _requests[_dispute.requestId];
    if (msg.sender != address(_request.resolutionModule)) revert Oracle_NotResolutionModule(msg.sender);
    _dispute.status = _status;
    _request.disputeModule.updateDisputeStatus(_disputeId, _dispute);
  }

  function validModule(bytes32 _requestId, address _module) external view returns (bool _validModule) {
    Request memory _request = _requests[_requestId];
    _validModule = address(_request.requestModule) == _module || address(_request.responseModule) == _module
      || address(_request.disputeModule) == _module || address(_request.resolutionModule) == _module
      || address(_request.finalityModule) == _module;
  }

  function getFinalizedResponse(bytes32 _requestId) external view returns (Response memory _response) {
    _response = _finalizedResponses[_requestId];
  }

  function getResponseIds(bytes32 _requestId) external view returns (bytes32[] memory _ids) {
    _ids = _responseIds[_requestId];
  }

  function finalize(bytes32 _requestId, bytes32 _finalizedResponseId) external {
    if (_finalizedResponses[_requestId].createdAt != 0) revert Oracle_AlreadyFinalized(_requestId);

    Request memory _request = _requests[_requestId];
    Response storage _response = _responses[_finalizedResponseId];

    if (_response.requestId != _requestId || _response.createdAt == 0) {
      revert Oracle_InvalidFinalizedResponse(_finalizedResponseId);
    }

    DisputeStatus _disputeStatus = _disputes[disputeOf[_finalizedResponseId]].status;
    if (_disputeStatus == DisputeStatus.Active || _disputeStatus == DisputeStatus.Won) {
      revert Oracle_InvalidFinalizedResponse(_finalizedResponseId);
    }

    _finalizedResponses[_requestId] = _response;

    if (address(_request.finalityModule) != address(0)) {
      _request.finalityModule.finalizeRequest(_requestId);
    }

    if (address(_request.resolutionModule) != address(0)) {
      _request.resolutionModule.finalizeRequest(_requestId);
    }

    _request.disputeModule.finalizeRequest(_requestId);
    _request.responseModule.finalizeRequest(_requestId);
    _request.requestModule.finalizeRequest(_requestId);
  }

  function _createRequest(NewRequest memory _request) internal returns (bytes32 _requestId) {
    uint256 _requestNonce = totalRequestCount++;
    _requestId = keccak256(abi.encodePacked(msg.sender, address(this), _requestNonce));
    _requestIds[_requestNonce] = _requestId;

    Request memory _storedRequest = Request({
      ipfsHash: _request.ipfsHash,
      requestModule: _request.requestModule,
      responseModule: _request.responseModule,
      disputeModule: _request.disputeModule,
      resolutionModule: _request.resolutionModule,
      finalityModule: _request.finalityModule,
      requester: msg.sender,
      nonce: _requestNonce,
      createdAt: block.timestamp
    });

    _requests[_requestId] = _storedRequest;

    _request.requestModule.setupRequest(_requestId, _request.requestModuleData);
    _request.responseModule.setupRequest(_requestId, _request.responseModuleData);
    _request.disputeModule.setupRequest(_requestId, _request.disputeModuleData);

    if (address(_request.resolutionModule) != address(0)) {
      _request.resolutionModule.setupRequest(_requestId, _request.resolutionModuleData);
    }

    if (address(_request.finalityModule) != address(0)) {
      _request.finalityModule.setupRequest(_requestId, _request.finalityModuleData);
    }
  }

  function _getRequest(bytes32 _requestId) internal view returns (FullRequest memory _fullRequest) {
    Request memory _storedRequest = _requests[_requestId];

    _fullRequest = FullRequest({
      requestModuleData: _storedRequest.requestModule.requestData(_requestId),
      responseModuleData: _storedRequest.responseModule.requestData(_requestId),
      disputeModuleData: _storedRequest.disputeModule.requestData(_requestId),
      resolutionModuleData: address(_storedRequest.resolutionModule) == address(0)
        ? bytes('')
        : _storedRequest.resolutionModule.requestData(_requestId),
      finalityModuleData: address(_storedRequest.finalityModule) == address(0)
        ? bytes('')
        : _storedRequest.finalityModule.requestData(_requestId),
      ipfsHash: _storedRequest.ipfsHash,
      requestModule: _storedRequest.requestModule,
      responseModule: _storedRequest.responseModule,
      disputeModule: _storedRequest.disputeModule,
      resolutionModule: _storedRequest.resolutionModule,
      finalityModule: _storedRequest.finalityModule,
      requester: _storedRequest.requester,
      nonce: _storedRequest.nonce,
      createdAt: _storedRequest.createdAt,
      requestId: _requestId
    });
  }
}
