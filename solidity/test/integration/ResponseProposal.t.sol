// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_ResponseProposal is IntegrationBase {
  bytes32 internal _requestId;

  function setUp() public override {
    super.setUp();

    mockRequest.nonce = uint96(oracle.totalRequestCount());

    vm.prank(requester);
    _requestId = oracle.createRequest(mockRequest, _ipfsHash);
  }

  function test_proposeResponse_validResponse(bytes memory _response) public {
    mockResponse.response = _response;

    vm.prank(proposer);
    oracle.proposeResponse(mockRequest, mockResponse);

    bytes32[] memory _responseIds = oracle.getResponseIds(_requestId);

    // Check: response data is correctly stored?
    assertEq(_responseIds.length, 1);
    assertEq(_responseIds[0], _getId(mockResponse));
  }

  function test_proposeResponse_finalizedRequest(uint256 _timestamp) public {
    _timestamp = bound(_timestamp, _expectedDeadline + _baseDisputeWindow, type(uint128).max);

    vm.prank(proposer);
    oracle.proposeResponse(mockRequest, mockResponse);

    vm.warp(_timestamp);
    oracle.finalize(mockRequest, mockResponse);

    mockResponse.response = abi.encode(_timestamp);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    vm.prank(proposer);
    oracle.proposeResponse(mockRequest, mockResponse);
  }
}
