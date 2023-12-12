// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './IntegrationBase.sol';

contract Integration_Finalization is IntegrationBase {
  address internal _finalizer = makeAddr('finalizer');
  address internal _callbackTarget = makeAddr('target');

  function setUp() public override {
    super.setUp();
    vm.etch(_callbackTarget, hex'069420');
  }

  /**
   * @notice Test to check if another module can be set as callback module.
   */
  function test_targetIsAnotherModule() public {
    mockRequest.finalityModuleData = abi.encode(
      IMockFinalityModule.RequestParameters({
        target: address(_finalityModule),
        data: abi.encodeWithSignature('callback()')
      })
    );

    vm.prank(requester);
    oracle.createRequest(mockRequest, _ipfsHash);

    _jumpToFinalization();

    vm.warp(block.timestamp + _baseDisputeWindow);
    vm.prank(_finalizer);
    oracle.finalize(mockRequest, mockResponse);
  }

  /**
   * @notice Test to check that finalization data is set and callback calls are made.
   */
  function test_makeAndIgnoreLowLevelCalls(bytes memory _calldata) public {
    mockRequest.finalityModuleData =
      abi.encode(IMockFinalityModule.RequestParameters({target: _callbackTarget, data: _calldata}));

    vm.prank(requester);
    bytes32 _requestId = oracle.createRequest(mockRequest, _ipfsHash);

    _jumpToFinalization();

    // Check: all low-level calls are made?
    vm.expectCall(_callbackTarget, _calldata);

    vm.warp(block.timestamp + _baseDisputeWindow);
    vm.prank(_finalizer);
    oracle.finalize(mockRequest, mockResponse);

    bytes32 _responseId = oracle.finalizedResponseId(_requestId);
    // Check: is request finalized?
    assertEq(_responseId, _getId(mockResponse));
  }

  /**
   * @notice Test to check that finalizing a request that has no response will succeed.
   */
  function test_finalizeWithoutResponse() public {
    vm.prank(requester);
    oracle.createRequest(mockRequest, _ipfsHash);

    mockResponse.requestId = bytes32(0);

    // Check: finalizes if request has no response?
    vm.prank(_finalizer);
    oracle.finalize(mockRequest, mockResponse);
  }

  /**
   * @notice Test to check that finalizing a request with a ongoing dispute will revert.
   */
  function test_revertFinalizeWithDisputedResponse() public {
    mockRequest.finalityModuleData =
      abi.encode(IMockFinalityModule.RequestParameters({target: _callbackTarget, data: bytes('')}));

    mockResponse.requestId = _getId(mockRequest);
    mockDispute.requestId = mockResponse.requestId;
    mockDispute.responseId = _getId(mockResponse);

    vm.prank(requester);
    oracle.createRequest(mockRequest, _ipfsHash);

    vm.prank(proposer);
    oracle.proposeResponse(mockRequest, mockResponse);

    vm.prank(disputer);
    oracle.disputeResponse(mockRequest, mockResponse, mockDispute);

    vm.prank(_finalizer);
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);
    oracle.finalize(mockRequest, mockResponse);
  }

  /**
   * @notice Test to check that finalizing a request with a ongoing dispute will revert.
   */
  function test_revertFinalizeInDisputeWindow() public {
    mockRequest.finalityModuleData =
      abi.encode(IMockFinalityModule.RequestParameters({target: _callbackTarget, data: bytes('')}));

    vm.prank(requester);
    oracle.createRequest(mockRequest, _ipfsHash);
  }

  /**
   * @notice Test to check that finalizing a request without disputes triggers callback calls and executes without reverting.
   */
  function test_finalizeWithUndisputedResponse(bytes calldata _calldata) public {
    mockRequest.finalityModuleData =
      abi.encode(IMockFinalityModule.RequestParameters({target: _callbackTarget, data: _calldata}));

    vm.expectCall(_callbackTarget, _calldata);
    vm.prank(requester);
    oracle.createRequest(mockRequest, _ipfsHash);

    _jumpToFinalization();

    vm.warp(block.timestamp + _baseDisputeWindow);
    vm.prank(_finalizer);
    oracle.finalize(mockRequest, mockResponse);
  }

  /**
   * @notice Internal helper function to setup the finalization stage of a request.
   */
  function _jumpToFinalization() internal returns (bytes32 _responseId) {
    mockResponse.requestId = _getId(mockRequest);

    vm.prank(proposer);
    _responseId = oracle.proposeResponse(mockRequest, mockResponse);

    vm.warp(_expectedDeadline + 1);
  }
}
