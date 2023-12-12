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

    vm.prank(requester);
    _requestId = oracle.createRequest(mockRequest, _ipfsHash);

    mockResponse.requestId = _requestId;

    vm.prank(proposer);
    _responseId = oracle.proposeResponse(mockRequest, mockResponse);
  }

  function test_disputeResponse_alreadyFinalized() public {
    vm.warp(_expectedDeadline + _baseDisputeWindow);
    oracle.finalize(mockRequest, mockResponse);

    vm.prank(disputer);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);
  }

  function test_disputeResponse_alreadyDisputed() public {
    vm.prank(disputer);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);

    vm.prank(disputer);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);
  }
}
