/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {Oracle} from 'solidity/contracts/Oracle.sol';
import {IOracle} from 'solidity/interfaces/IOracle.sol';
import {EnumerableSet} from 'node_modules/@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

contract MockOracle is Oracle, Test {
  /// Mocked State Variables
  function set_totalRequestCount(uint256 _totalRequestCount) public {
    totalRequestCount = _totalRequestCount;
  }

  function mock_call_totalRequestCount(uint256 _totalRequestCount) public {
    vm.mockCall(address(this), abi.encodeWithSignature('totalRequestCount()'), abi.encode(_totalRequestCount));
  }

  function set_disputeOf(bytes32 _key, bytes32 _value) public {
    disputeOf[_key] = _value;
  }

  function mock_call_disputeOf(bytes32 _key, bytes32 _value) public {
    vm.mockCall(address(this), abi.encodeWithSignature('', _key), abi.encode(_value));
  }

  /// Mocked External Functions
  function mock_call_createRequest(IOracle.NewRequest memory _request, bytes32 _requestId) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('createRequest(IOracle.NewRequest)', _request), abi.encode(_requestId)
    );
  }

  function mock_call_createRequests(
    IOracle.NewRequest[] calldata _requestsData,
    bytes32[] memory _batchRequestsIds
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('createRequests(IOracle.NewRequest[])', _requestsData),
      abi.encode(_batchRequestsIds)
    );
  }

  function mock_call_listRequests(uint256 _startFrom, uint256 _batchSize, IOracle.FullRequest[] memory _list) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('listRequests(uint256, uint256)', _startFrom, _batchSize),
      abi.encode(_list)
    );
  }

  function mock_call_listRequestIds(uint256 _startFrom, uint256 _batchSize, bytes32[] memory _list) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('listRequestIds(uint256, uint256)', _startFrom, _batchSize),
      abi.encode(_list)
    );
  }

  function mock_call_getResponse(bytes32 _responseId, IOracle.Response memory _response) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getResponse(bytes32)', _responseId), abi.encode(_response));
  }

  function mock_call_getRequestId(uint256 _nonce, bytes32 _requestId) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getRequestId(uint256)', _nonce), abi.encode(_requestId));
  }

  function mock_call_getRequestByNonce(uint256 _nonce, IOracle.Request memory _request) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getRequestByNonce(uint256)', _nonce), abi.encode(_request));
  }

  function mock_call_getRequest(bytes32 _requestId, IOracle.Request memory _request) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getRequest(bytes32)', _requestId), abi.encode(_request));
  }

  function mock_call_getFullRequest(bytes32 _requestId, IOracle.FullRequest memory _request) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getFullRequest(bytes32)', _requestId), abi.encode(_request));
  }

  function mock_call_getDispute(bytes32 _disputeId, IOracle.Dispute memory _dispute) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getDispute(bytes32)', _disputeId), abi.encode(_dispute));
  }

  function mock_call_proposeResponse(
    bytes32 _requestId,
    bytes calldata _responseData,
    bytes calldata _moduleData,
    bytes32 _responseId
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('proposeResponse(bytes32, bytes, bytes)', _requestId, _responseData, _moduleData),
      abi.encode(_responseId)
    );
  }

  function mock_call_proposeResponse(
    address _proposer,
    bytes32 _requestId,
    bytes calldata _responseData,
    bytes calldata _moduleData,
    bytes32 _responseId
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature(
        'proposeResponse(address, bytes32, bytes, bytes)', _proposer, _requestId, _responseData, _moduleData
      ),
      abi.encode(_responseId)
    );
  }

  function mock_call_deleteResponse(bytes32 _responseId) public {
    vm.mockCall(address(this), abi.encodeWithSignature('deleteResponse(bytes32)', _responseId), abi.encode());
  }

  function mock_call_disputeResponse(
    bytes32 _requestId,
    bytes32 _responseId,
    bytes calldata _moduleData,
    bytes32 _disputeId
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('disputeResponse(bytes32, bytes32, bytes)', _requestId, _responseId, _moduleData),
      abi.encode(_disputeId)
    );
  }

  function mock_call_escalateDispute(bytes32 _disputeId, bytes calldata _moduleData) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('escalateDispute(bytes32, bytes)', _disputeId, _moduleData), abi.encode()
    );
  }

  function mock_call_resolveDispute(bytes32 _disputeId, bytes calldata _moduleData) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('resolveDispute(bytes32, bytes)', _disputeId, _moduleData), abi.encode()
    );
  }

  function mock_call_updateDisputeStatus(
    bytes32 _disputeId,
    IOracle.DisputeStatus _status,
    bytes calldata _moduleData
  ) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature(
        'updateDisputeStatus(bytes32, IOracle.DisputeStatus, bytes)', _disputeId, _status, _moduleData
      ),
      abi.encode()
    );
  }

  function mock_call_allowedModule(bytes32 _requestId, address _module, bool _allowedModule) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('allowedModule(bytes32, address)', _requestId, _module),
      abi.encode(_allowedModule)
    );
  }

  function mock_call_isParticipant(bytes32 _requestId, address _user, bool _isParticipant) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('isParticipant(bytes32, address)', _requestId, _user),
      abi.encode(_isParticipant)
    );
  }

  function mock_call_getFinalizedResponseId(bytes32 _requestId, bytes32 _finalizedResponseId) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('getFinalizedResponseId(bytes32)', _requestId),
      abi.encode(_finalizedResponseId)
    );
  }

  function mock_call_getFinalizedResponse(bytes32 _requestId, IOracle.Response memory _response) public {
    vm.mockCall(
      address(this), abi.encodeWithSignature('getFinalizedResponse(bytes32)', _requestId), abi.encode(_response)
    );
  }

  function mock_call_getResponseIds(bytes32 _requestId, bytes32[] memory _ids) public {
    vm.mockCall(address(this), abi.encodeWithSignature('getResponseIds(bytes32)', _requestId), abi.encode(_ids));
  }

  function mock_call_finalize(bytes32 _requestId, bytes32 _finalizedResponseId) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature('finalize(bytes32, bytes32)', _requestId, _finalizedResponseId),
      abi.encode()
    );
  }

  function mock_call_finalize(bytes32 _requestId) public {
    vm.mockCall(address(this), abi.encodeWithSignature('finalize(bytes32)', _requestId), abi.encode());
  }
}
