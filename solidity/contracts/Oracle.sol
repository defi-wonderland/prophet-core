// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IOracle} from '@interfaces/IOracle.sol';
import {IAccountingExtension} from '@interfaces/IAccountingExtension.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IWETH9} from '../interfaces/external/IWETH9.sol';

contract Oracle is IOracle {
  mapping(bytes32 _requestId => Request) internal _requests;
  mapping(bytes32 _responseId => Response) internal _responses;
  mapping(bytes32 _requestId => bytes32[] _responseId) internal _responseIds;
  mapping(bytes32 _requestId => Response) internal _finalizedResponses;
  uint256 internal _nonce;

  function createRequest(Request memory _request) external payable returns (bytes32 _requestId) {
    uint256 _requestNonce = ++_nonce;
    _requestId = keccak256(abi.encodePacked(msg.sender, address(this), _requestNonce));
    _request.nonce = _requestNonce;
    _request.requester = msg.sender;
    _request.finalizedResponseId = bytes32('');
    _request.disputeId = bytes32('');
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
  function createRequests(bytes[] calldata _requestsData) external returns (bytes32[] memory _requestIds) {}

  function getResponse(bytes32 _responseId) external view returns (Response memory _response) {
    _response = _responses[_responseId];
  }

  function getRequest(bytes32 _requestId) external view returns (Request memory _request) {
    _request = _requests[_requestId];
  }

  function proposeResponse(bytes32 _requestId, bytes calldata _responseData) external returns (bytes32 _responseId) {
    Request memory _request = _requests[_requestId];
    _responseId = keccak256(abi.encodePacked(msg.sender, address(this), _requestId));
    _responses[_responseId] = _request.responseModule.propose(_requestId, msg.sender, _responseData);
    _responseIds[_requestId].push(_responseId);
  }

  function disputeResponse(bytes32 _requestId) external returns (bytes32 _disputeId) {
    Request memory _request = _requests[_requestId];
    bool _canDispute = _request.disputeModule.canDispute(_requestId, msg.sender);
    if (_canDispute) {
      _disputeId = keccak256(abi.encodePacked(msg.sender, _requestId));
      _request.disputeId = _disputeId;
      _requests[_requestId] = _request;
    } else {
      revert Oracle_CannotDispute(_requestId, msg.sender);
    }
  }

  function validModule(bytes32 _requestId, address _module) external view returns (bool _validModule) {
    IOracle.Request memory _request = _requests[_requestId];
    _validModule = address(_request.requestModule) == _module || address(_request.responseModule) == _module
      || address(_request.disputeModule) == _module || address(_request.finalityModule) == _module;
  }

  function slash(bytes32 _requestId, IERC20 _token, address _slashed, address _disputer, uint256 _amount) external {
    // Request memory _request = _requests[_requestId];
    // IAccountingExtension _accountingExtension = _request.responseModule.getExtension(_requestId);
    // if (address(_accountingExtension) == address(0)) revert Oracle_NoExtensionSet(_requestId);
    // _accountingExtension.slash(_token, _slashed, _disputer, _amount);
  }

  function canPropose(bytes32 _requestId, address _proposer) external returns (bool _canPropose) {
    _canPropose = _requests[_requestId].responseModule.canPropose(_requestId, _proposer);
  }

  function canDispute(bytes32 _requestId, address _disputer) external returns (bool _canDispute) {
    _canDispute = _requests[_requestId].disputeModule.canDispute(_requestId, _disputer);
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

    if (address(_request.requestModule) != address(0)) {
      _request.requestModule.finalizeRequest(_requestId);
    }

    if (address(_request.responseModule) != address(0)) {
      _request.responseModule.finalizeRequest(_requestId);
    }

    if (address(_request.disputeModule) != address(0)) {
      _request.disputeModule.finalizeRequest(_requestId);
    }

    if (address(_request.finalityModule) != address(0)) {
      _request.finalityModule.finalizeRequest(_requestId);
    }
  }
}
