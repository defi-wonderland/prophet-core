// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_ResponseProposal is IntegrationBase {
  bytes32 internal _requestId;

  function setUp() public override {
    super.setUp();

    _expectedDeadline = block.timestamp + BLOCK_TIME * 600;

    mockRequest.requestModuleData = abi.encode(
      IMockRequestModule.RequestParameters({
        url: _expectedUrl,
        body: _expectedBody,
        accountingExtension: _accountingExtension,
        paymentToken: usdc,
        paymentAmount: _expectedReward
      })
    );

    mockRequest.responseModuleData = abi.encode(
      IMockResponseModule.RequestParameters({
        accountingExtension: _accountingExtension,
        bondToken: usdc,
        bondAmount: _expectedBondAmount,
        deadline: _expectedDeadline,
        disputeWindow: _baseDisputeWindow
      })
    );

    mockRequest.disputeModuleData = abi.encode(
      IMockDisputeModule.RequestParameters({
        accountingExtension: _accountingExtension,
        bondToken: usdc,
        bondAmount: _expectedBondAmount
      })
    );

    mockRequest.resolutionModuleData = abi.encode();

    mockRequest.finalityModuleData = abi.encode(
      IMockFinalityModule.RequestParameters({target: address(_mockCallback), data: abi.encode(_expectedCallbackValue)})
    );

    mockRequest.requestModule = address(_requestModule);
    mockRequest.responseModule = address(_responseModule);
    mockRequest.disputeModule = address(_disputeModule);
    mockRequest.resolutionModule = address(_resolutionModule);
    mockRequest.finalityModule = address(_finalityModule);

    mockRequest.nonce = uint96(oracle.totalRequestCount());
    mockRequest.requester = requester;

    mockResponse.requestId = _getId(mockRequest);

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

    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    vm.prank(proposer);
    oracle.proposeResponse(mockRequest, mockResponse);
  }
}
