// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IOracle} from '../interfaces/IOracle.sol';
import {IAccountingExtension} from '../interfaces/extensions/IAccountingExtension.sol';
import {IWETH9} from '../interfaces/external/IWETH9.sol';

contract Oracle is IOracle {
  mapping(bytes32 _responseId => bytes32 _disputeId) public disputeOf;

  mapping(bytes32 _requestId => Request) internal _requests;

  mapping(bytes32 _responseId => Response) internal _responses;
  mapping(bytes32 _requestId => bytes32[] _responseId) internal _responseIds;

  mapping(bytes32 _requestId => Response) internal _finalizedResponses;

  mapping(bytes32 _disputeId => Dispute) internal _disputes;

  mapping(uint256 _nonce => bytes32 _id) internal _requestIds;
  uint256 internal _nonce;

  function createRequest(Request memory _request) external payable returns (bytes32 _requestId) {
    uint256 _requestNonce = ++_nonce;
    _requestId = keccak256(abi.encodePacked(msg.sender, address(this), _requestNonce));
    _requestIds[_requestNonce] = _requestId;
    _request.nonce = _requestNonce;
    _request.requester = msg.sender;
    _request.createdAt = block.timestamp;
    _request.finalizedResponseId = bytes32('');
    _requests[_requestId] = _request;

    _request.requestModule.setupRequest(_requestId, _request.requestModuleData);
    _request.responseModule.setupRequest(_requestId, _request.responseModuleData);

    if (address(_request.disputeModule) != address(0)) {
      _request.disputeModule.setupRequest(_requestId, _request.disputeModuleData);
    }

    if (address(_request.finalityModule) != address(0)) {
      _request.finalityModule.setupRequest(_requestId, _request.finalityModuleData);
    }
  }

  // TODO: Same as `createRequest` but with multiple requests passed in as an array
  function createRequests(bytes[] calldata _requestsData) external returns (bytes32[] memory _requestsIds) {}

  function listRequests(uint256 _startFrom, uint256 _batchSize) external view returns (Request[] memory _list) {
    uint256 _totalRequestsCount = _nonce;
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

  function getResponse(bytes32 _responseId) external view returns (Response memory _response) {
    _response = _responses[_responseId];
  }

  function getRequest(bytes32 _requestId) external view returns (Request memory _request) {
    _request = _requests[_requestId];
  }

  function getDispute(bytes32 _disputeId) external view returns (Dispute memory _dispute) {
    _dispute = _disputes[_disputeId];
  }

  function proposeResponse(bytes32 _requestId, bytes calldata _responseData) external returns (bytes32 _responseId) {
    bool _canPropose = _requests[_requestId].responseModule.canPropose(_requestId, msg.sender);
    if (_canPropose) {
      Request memory _request = _requests[_requestId];
      _responseId = keccak256(abi.encodePacked(msg.sender, address(this), _requestId));
      _responses[_responseId] = _request.responseModule.propose(_requestId, msg.sender, _responseData);
      _responseIds[_requestId].push(_responseId);
    } else {
      revert Oracle_CannotPropose(_requestId, msg.sender);
    }
  }

  function disputeResponse(bytes32 _requestId, bytes32 _responseId) external returns (bytes32 _disputeId) {
    if (disputeOf[_responseId] != bytes32('')) revert Oracle_ResponseAlreadyDisputed(_responseId);

    Request memory _request = _requests[_requestId];
    bool _canDispute = _request.disputeModule.canDispute(_requestId, msg.sender);

    if (_canDispute) {
      _disputeId = keccak256(abi.encodePacked(msg.sender, _requestId));
      _disputes[_disputeId] =
        _request.disputeModule.disputeResponse(_requestId, _responseId, msg.sender, _responses[_responseId].proposer);
      disputeOf[_responseId] = _disputeId;
    } else {
      revert Oracle_CannotDispute(_requestId, msg.sender);
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
      || address(_request.disputeModule) == _module || address(_request.finalityModule) == _module;
  }

  function canPropose(bytes32 _requestId, address _proposer) external returns (bool _canPropose) {
    _canPropose = _requests[_requestId].responseModule.canPropose(_requestId, _proposer);
  }

  function canDispute(bytes32 _responseId, address _disputer) external returns (bool _canDispute) {
    bytes32 _requestId = _responses[_responseId].requestId;
    _canDispute =
      disputeOf[_responseId] == bytes32('') && _requests[_requestId].disputeModule.canDispute(_requestId, _disputer);
  }

  function getFinalizedResponse(bytes32 _requestId) external view returns (Response memory _response) {
    _response = _responses[_requests[_requestId].finalizedResponseId];
  }

  function getResponseIds(bytes32 _requestId) external view returns (bytes32[] memory _ids) {
    _ids = _responseIds[_requestId];
  }

  function finalize(bytes32 _requestId) external {
    // TODO: Save the finalizedResponseId
    Request memory _request = _requests[_requestId];

    _request.requestModule.finalizeRequest(_requestId);
    _request.responseModule.finalizeRequest(_requestId);

    if (address(_request.disputeModule) != address(0)) {
      _request.disputeModule.finalizeRequest(_requestId);
    }

    if (address(_request.finalityModule) != address(0)) {
      _request.finalityModule.finalizeRequest(_requestId);
    }
  }
}
