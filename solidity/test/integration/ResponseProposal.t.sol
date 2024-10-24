// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_ResponseProposal is IntegrationBase {
  bytes32 internal _requestId;

  function setUp() public override {
    super.setUp();

    mockRequest.nonce = uint96(oracle.totalRequestCount());

    address _badRequester = makeAddr('badRequester');
    mockAccessControl.user = _badRequester;

    // Revert if not approved to create request
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AccessControlModuleNotApproved.selector));
    oracle.createRequest(mockRequest, _ipfsHash, mockAccessControl);

    vm.stopPrank();

    // Revert if has no access to create request
    mockAccessControl.user = requester;
    vm.expectRevert(abi.encodeWithSelector(IAccessController.AccessControlData_NoAccess.selector));
    vm.prank(badCaller);
    oracle.createRequest(mockRequest, _ipfsHash, mockAccessControl);

    // Create request
    vm.startPrank(caller);
    _requestId = oracle.createRequest(mockRequest, _ipfsHash, mockAccessControl);
  }

  function test_proposeResponse_validResponse(bytes memory _response) public {
    mockResponse.response = _response;

    // Revert if not approved to create request
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AccessControlModuleNotApproved.selector));
    address _badProposer = makeAddr('badProposer');
    mockAccessControl.user = _badProposer;
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);

    vm.stopPrank();

    // Revert if has no access to create request
    mockAccessControl.user = proposer;
    vm.expectRevert(abi.encodeWithSelector(IAccessController.AccessControlData_NoAccess.selector));
    vm.prank(badCaller);
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);

    vm.startPrank(caller);
    // Propose response
    mockAccessControl.user = proposer;
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);

    bytes32[] memory _responseIds = oracle.getResponseIds(_requestId);

    // Check: response data is correctly stored?
    assertEq(_responseIds.length, 1);
    assertEq(_responseIds[0], _getId(mockResponse));
  }

  function test_proposeResponse_finalizedRequest(uint256 _timestamp) public {
    _timestamp = bound(_timestamp, _expectedDeadline + _baseDisputeWindow, type(uint128).max);

    // Propose response
    mockAccessControl.user = proposer;
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);

    // Finalize request
    vm.warp(_timestamp);
    mockAccessControl.user = finalizer;
    oracle.finalize(mockRequest, mockResponse, mockAccessControl);

    // Revert if the request is already finalized
    mockAccessControl.user = proposer;
    mockResponse.response = abi.encode(_timestamp);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    oracle.proposeResponse(mockRequest, mockResponse, mockAccessControl);
  }
}
