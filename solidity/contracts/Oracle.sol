// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IOracle} from '../interfaces/IOracle.sol';
import {IAccountingExtension} from '../interfaces/extensions/IAccountingExtension.sol';

contract Oracle is IOracle {
  mapping(bytes32 _responseId => bytes32 _disputeId) public disputeOf;

  mapping(bytes32 _requestId => Request) internal _requests;

  mapping(bytes32 _responseId => Response) internal _responses;
  mapping(bytes32 _requestId => bytes32[] _responseId) internal _responseIds;

  mapping(bytes32 _requestId => Response) internal _finalizedResponses;

  mapping(bytes32 _disputeId => Dispute) internal _disputes;

  mapping(uint256 _nonce => bytes32 _id) internal _requestIds;

  uint256 internal _nonce;

  uint256 internal _responseNonce;

  function createRequest(Request memory _request) external payable returns (bytes32 _requestId) {
    uint256 _requestNonce = _nonce++;
    _requestId = keccak256(abi.encodePacked(msg.sender, address(this), _requestNonce));
    _requestIds[_requestNonce] = _requestId;
    _request.nonce = _requestNonce;
    _request.requester = msg.sender;
    _request.createdAt = block.timestamp;
    _requests[_requestId] = _request;

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

  // TODO: Same as `createRequest` but with multiple requests passed in as an array
  function createRequests(bytes[] calldata _requestsData) external returns (bytes32[] memory _requestsIds) {}

  function listRequests(uint256 _startFrom, uint256 _batchSize) external view returns (Request[] memory _list) {
    uint256 _totalRequestsCount = _nonce;

    // If trying to collect unexisting requests only, return empty array
    if (_startFrom > _totalRequestsCount) {
      return _list;
    }

    if (_batchSize > _totalRequestsCount - _startFrom) {
      _batchSize = _totalRequestsCount - _startFrom;
    }

    _list = new Request[](_batchSize);

    uint256 _index;
    while (_index < _batchSize) {
      _list[_index] = _requests[_requestIds[_startFrom + _index]];

      unchecked {
        ++_index;
      }
    }

    return _list;
  }

  function listRequestIds(uint256 _startFrom, uint256 _batchSize) external view returns (bytes32[] memory _list) {
    uint256 _totalRequestsCount = _nonce;

    // If trying to collect unexisting requests only, return empty array
    if (_startFrom > _totalRequestsCount) {
      return _list;
    }

    if (_batchSize > _totalRequestsCount - _startFrom) {
      _batchSize = _totalRequestsCount - _startFrom;
    }

    _list = new bytes32[](_batchSize);

    uint256 _index;
    while (_index < _batchSize) {
      _list[_index] = _requestIds[_startFrom + _index];

      unchecked {
        ++_index;
      }
    }

    return _list;
  }

  function getResponse(bytes32 _responseId) external view returns (Response memory _response) {
    _response = _responses[_responseId];
  }

  function getRequest(bytes32 _requestId) external view returns (Request memory _request) {
    _request = _requests[_requestId];
  }

  function getDispute(bytes32 _disputeId) external view returns (Dispute memory _dispute) {
    _dispute = _disputes[_disputeId];
  }

  function getProposers(bytes32 _requestId) external view returns (address[] memory _proposers) {
    bytes32[] memory _responsesIds = _responseIds[_requestId];
    if (_responsesIds.length == 0) return _proposers;
    _proposers = new address[](_responsesIds.length);

    for (uint256 _i; _i < _responsesIds.length;) {
      _proposers[_i] = _responses[_responsesIds[_i]].proposer;

      unchecked {
        ++_i;
      }
    }
  }

  function proposeResponse(bytes32 _requestId, bytes calldata _responseData) external returns (bytes32 _responseId) {
    Request memory _request = _requests[_requestId];

    _responseId = keccak256(abi.encodePacked(msg.sender, address(this), _requestId, _responseNonce++));
    _responses[_responseId] = _request.responseModule.propose(_requestId, msg.sender, _responseData);
    _responseIds[_requestId].push(_responseId);
  }

  function disputeResponse(bytes32 _requestId, bytes32 _responseId) external returns (bytes32 _disputeId) {
    if (disputeOf[_responseId] != bytes32(0)) revert Oracle_ResponseAlreadyDisputed(_responseId);

    Request memory _request = _requests[_requestId];

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

  // TODO: discuss - should the Oracle have any reverts other than checking for empty values, or does this become too opinionated?
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
}
