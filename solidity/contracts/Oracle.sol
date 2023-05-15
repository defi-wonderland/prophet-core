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
    _requestId = keccak256(abi.encodePacked(msg.sender, ++_nonce));
    _request.finalizedResponseId = bytes32('');
    _request.disputeId = bytes32('');
    _requests[_requestId] = _request;

    _request.requestModule.setupRequest(_requestId, _request.requestModuleData);

    if (address(_request.responseModule) != address(0)) {
      _request.responseModule.setupRequest(_requestId, _request.responseModuleData);

      // TODO: the reward should be included somewhere in the data as bondSize != answering reward
      (IAccountingExtension _accountingExtension, IERC20 _bondToken, uint256 _bondSize) =
        _request.responseModule.getBondData(IOracle(address(this)), _requestId);
      if (address(_accountingExtension) != address(0)) {
        // Note: This assumes user has called approve and deposit beforehand on the AccountingExtension
        _accountingExtension.bond(msg.sender, _bondToken, _bondSize);
      }
    }

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
    bool _canPropose = _request.responseModule.canPropose(IOracle(address(this)), _requestId, msg.sender);
    if (_canPropose) {
      _responseId = keccak256(abi.encodePacked(msg.sender, _requestId));
      Response memory _response =
        Response({requestId: _requestId, disputeId: bytes32(''), response: _responseData, finalized: false});
      _responses[_responseId] = _response;
      _responseIds[_requestId].push(_responseId);
    } else {
      revert Oracle_CannotPropose(_requestId, msg.sender);
    }
  }

  function disputeResponse(bytes32 _requestId) external returns (bytes32 _disputeId) {
    Request memory _request = _requests[_requestId];
    bool _canDispute = _request.disputeModule.canDispute(IOracle(address(this)), _requestId, msg.sender);
    if (_canDispute) {
      _disputeId = keccak256(abi.encodePacked(msg.sender, _requestId));
      _request.disputeId = _disputeId;
      _requests[_requestId] = _request;
    } else {
      revert Oracle_CannotDispute(_requestId, msg.sender);
    }
  }

  function deposit(bytes32 _requestId, IERC20 _token, uint256 _amount) external payable {
    Request memory _request = _requests[_requestId];
    IAccountingExtension _accountingExtension = _request.responseModule.getExtension(IOracle(address(this)), _requestId);
    if (address(_accountingExtension) == address(0)) revert Oracle_NoExtensionSet(_requestId);
    _accountingExtension.deposit{value: msg.value}(msg.sender, IOracle(address(this)), _token, _amount);
  }

  function withdraw(bytes32 _requestId, IERC20 _token, uint256 _amount) external {
    Request memory _request = _requests[_requestId];
    IAccountingExtension _accountingExtension = _request.responseModule.getExtension(IOracle(address(this)), _requestId);
    if (address(_accountingExtension) == address(0)) revert Oracle_NoExtensionSet(_requestId);
    _accountingExtension.withdraw(msg.sender, IOracle(address(this)), _token, _amount);
  }

  function pay(bytes32 _requestId, IERC20 _token, address _payee, address _payer, uint256 _amount) external {
    Request memory _request = _requests[_requestId];
    IAccountingExtension _accountingExtension = _request.responseModule.getExtension(IOracle(address(this)), _requestId);
    if (address(_accountingExtension) == address(0)) revert Oracle_NoExtensionSet(_requestId);
    _accountingExtension.pay(_token, _payee, _payer, _amount);
  }

  function slash(bytes32 _requestId, IERC20 _token, address _slashed, address _disputer, uint256 _amount) external {
    Request memory _request = _requests[_requestId];
    IAccountingExtension _accountingExtension = _request.responseModule.getExtension(IOracle(address(this)), _requestId);
    if (address(_accountingExtension) == address(0)) revert Oracle_NoExtensionSet(_requestId);
    _accountingExtension.slash(_token, _slashed, _disputer, _amount);
  }

  function canPropose(bytes32 _requestId, address _proposer) external returns (bool _canPropose) {
    _canPropose = _requests[_requestId].responseModule.canPropose(IOracle(address(this)), _requestId, _proposer);
  }

  function canDispute(bytes32 _requestId, address _disputer) external returns (bool _canDispute) {
    _canDispute = _requests[_requestId].disputeModule.canDispute(IOracle(address(this)), _requestId, _disputer);
  }

  function getFinalizedResponse(bytes32 _requestId) external view returns (Response memory _response) {
    _response = _responses[_requests[_requestId].finalizedResponseId];
  }

  function getResponseIds(bytes32 _requestId) external view returns (bytes32[] memory _ids) {
    _ids = _responseIds[_requestId];
  }
}
