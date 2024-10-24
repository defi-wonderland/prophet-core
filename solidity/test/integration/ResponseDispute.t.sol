// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_ResponseDispute is IntegrationBase {
  bytes internal _responseData;
  bytes32 internal _requestId;
  bytes32 internal _responseId;

  function setUp() public override {
    super.setUp();

    _expectedDeadline = block.timestamp + BLOCK_TIME * 600;
    _responseData = abi.encode('response');

    mockRequest.nonce = uint96(oracle.totalRequestCount());

    mockAccessControl.user = requester;
    _requestId = oracle.createRequest(mockRequest, _ipfsHash, mockAccessControl);

    mockResponse.requestId = _requestId;

    mockAccessControl.user = proposer;
    _responseId = oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);
  }

  function test_disputeResponse_alreadyFinalized() public {
    vm.warp(_expectedDeadline + _baseDisputeWindow);
    mockAccessControl.user = finalizer;
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);

    mockAccessControl.user = disputer;
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }

  function test_disputeResponse_alreadyDisputed() public {
    mockAccessControl.user = disputer;
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute, mockAccessControl);

    address _anotherDisputer = makeAddr('anotherDisputer');
    mockDispute.disputer = _anotherDisputer;

    mockAccessControl.user = _anotherDisputer;
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute, mockAccessControl);
  }
}
